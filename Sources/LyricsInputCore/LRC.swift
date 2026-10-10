import Foundation
import SpikeCore

public enum InputError: Error, CustomStringConvertible {
    case invalid(String)
    public var description: String { switch self { case .invalid(let message): return message } }
}
/// Bounded import representation, not a finalized project format.
public struct LyricEntry: Equatable, Sendable {
    public let time: Time
    public let text: String
    public let sourceLine: Int
    public let suppliedBreaks: Bool
    public let segments: [TimedSegment]
    /// Explicit TTML end; nil preserves legacy next-event/final-hold semantics.
    public let intervalEnd: Time?
    public var timingProvenance: String { intervalEnd != nil ? (segments.isEmpty ? "supplied-ttml-paragraph-interval" : "supplied-ttml-paragraph-and-span-intervals") : segments.isEmpty ? "supplied-line-timestamp-with-explicit-offset" : "supplied-segment-boundaries-with-explicit-offset" }
    public init(time:Time,text:String,sourceLine:Int,suppliedBreaks:Bool,segments:[TimedSegment]=[],intervalEnd:Time?=nil) {
        self.time=time;self.text=text;self.sourceLine=sourceLine;self.suppliedBreaks=suppliedBreaks;self.segments=segments;self.intervalEnd=intervalEnd
    }
}
public struct LocalLyrics: Sendable {
    public let entries: [LyricEntry]
    public let offsetMilliseconds: Int64
    public let diagnostics: [String]
    public func focus(at time: Time) -> Int? {
        var low=0, high=entries.count
        while low<high { let mid=(low+high)/2; if entries[mid].time<=time { low=mid+1 } else { high=mid } }
        guard low>0,!entries[low-1].text.isEmpty,entries[low-1].intervalEnd.map({time<$0}) ?? true else { return nil }
        return low-1
    }
    public func validate(audioSamples: Int) throws -> OutputSchedule {
        let schedule=try OutputSchedule(audioSamples:audioSamples)
        guard entries.allSatisfy({$0.time<schedule.audioEnd}) else { throw InputError.invalid("A lyric event reaches or exceeds the decoded audio endpoint") }
        guard entries.allSatisfy({$0.intervalEnd.map { $0<=schedule.audioEnd } ?? true}) else { throw InputError.invalid("Explicit paragraph end exceeds the audio endpoint") }
        try validateSegments(audioEnd:schedule.audioEnd)
        return schedule
    }
}
public struct OutputSchedule: Equatable, Sendable {
    public let samples, frames: Int
    public let audioEnd, outputEnd: Time
    public init(audioSamples: Int) throws {
        guard (1...28_800_000).contains(audioSamples) else { throw InputError.invalid("Audio duration must be positive and no longer than ten minutes") }
        samples=audioSamples;frames=(audioSamples+799)/800
        audioEnd=Time(Int64(audioSamples),48_000);outputEnd=Time(Int64(frames),60)
    }
}
public enum LRCParser {
    public static let byteLimit=65_536, eventLimit=256
    public static func parse(_ data: Data) throws -> LocalLyrics {
        guard data.count<=byteLimit, var text=String(data:data,encoding:.utf8) else { throw InputError.invalid("Lyrics must be valid UTF-8 and no larger than 64 KiB") }
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        guard !text.unicodeScalars.contains(where:{$0.value<32 && ![9,10,13].contains($0.value) || $0.value==127}) else { throw InputError.invalid("Unsupported control character in lyrics") }
        text=text.replacingOccurrences(of:"\r\n",with:"\n")
        guard !text.contains("\r") else { throw InputError.invalid("Use LF or CRLF line delimiters") }
        struct Raw { var times:[Int64];var text:String;let line:Int }
        var rows:[Raw]=[],continuation:Int?,offset:Int64?,diagnostics:[String]=[]
        let timestamp=try NSRegularExpression(pattern:"^([0-9]{2,}):([0-9]{2})(?:\\.([0-9]{1,3}))?$")
        let enhanced=try NSRegularExpression(pattern:"<[0-9]+:[0-9]")
        for (index,line) in text.components(separatedBy:"\n").enumerated() {
            let number=index+1
            if line.isEmpty { continue }
            if line.hasPrefix("|") {
                guard let i=continuation,!rows[i].text.isEmpty,line.count>1 else { throw InputError.invalid("Invalid multiline continuation at line \(number)") }
                rows[i].text += "\n"+line.dropFirst();continue
            }
            continuation=nil
            var rest=line,times:[Int64]=[]
            while rest.hasPrefix("["),let end=rest.firstIndex(of:"]") {
                let token=String(rest[rest.index(after:rest.startIndex)..<end])
                let ns=token as NSString
                if let match=timestamp.firstMatch(in:token,range:NSRange(location:0,length:ns.length)) {
                    guard let minutes=Int64(ns.substring(with:match.range(at:1))),minutes<=10,
                          let seconds=Int64(ns.substring(with:match.range(at:2))),seconds<60 else { throw InputError.invalid("Timestamp out of range at line \(number)") }
                    let fraction=match.range(at:3).location == NSNotFound ? "" : ns.substring(with:match.range(at:3))
                    let ms=fraction.isEmpty ? 0 : Int64(fraction+String(repeating:"0",count:3-fraction.count))!
                    guard times.count<eventLimit else { throw InputError.invalid("At most 256 timestamps are supported on one entry") }
                    times.append((minutes*60+seconds)*1000+ms)
                    rest=String(rest[rest.index(after:end)...]);continue
                }
                guard times.isEmpty,rest==line,end==line.index(before:line.endIndex),let colon=token.firstIndex(of:":") else { throw InputError.invalid("Malformed or unsupported tag at line \(number)") }
                let name=String(token[..<colon]),value=String(token[token.index(after:colon)...])
                if name=="offset" {
                    let digits=value.first=="-" || value.first=="+" ? String(value.dropFirst()) : value
                    guard offset==nil,!digits.isEmpty,digits.utf8.allSatisfy({(48...57).contains($0)}),let parsed=Int64(value),(-600_000...600_000).contains(parsed) else { throw InputError.invalid("Invalid or repeated offset at line \(number)") }
                    offset=parsed
                } else if ["ar","ti","al","by","re","ve"].contains(name) {
                    diagnostics.append("Ignored metadata tag \(name) at line \(number)")
                } else { throw InputError.invalid("Unsupported tag at line \(number)") }
                rest="";break
            }
            if times.isEmpty {
                guard rest.isEmpty else { throw InputError.invalid("Expected a timestamp at line \(number)") }
                continue
            }
            guard enhanced.firstMatch(in:rest,range:NSRange(location:0,length:(rest as NSString).length))==nil else { throw InputError.invalid("Enhanced LRC timing is unsupported at line \(number)") }
            rows.append(Raw(times:times,text:rest,line:number));continuation=rows.count-1
        }
        var entries:[LyricEntry]=[]
        for row in rows {
            guard enhanced.firstMatch(in:row.text,range:NSRange(location:0,length:(row.text as NSString).length))==nil else { throw InputError.invalid("Enhanced LRC timing is unsupported at line \(row.line)") }
            guard row.text.utf16.count<500,row.text.components(separatedBy:"\n").count<=4,
                  row.text.isEmpty || row.text.components(separatedBy:"\n").allSatisfy({!$0.trimmingCharacters(in:.whitespaces).isEmpty}) else { throw InputError.invalid("Paragraph size or empty-line constraint at line \(row.line)") }
            for raw in row.times {
                let ms=raw+(offset ?? 0)
                guard (0...600_000).contains(ms) else { throw InputError.invalid("Effective timestamp outside 0–600 seconds at line \(row.line)") }
                entries.append(.init(time:Time(ms,1000),text:row.text,sourceLine:row.line,suppliedBreaks:row.text.contains("\n")))
                guard entries.count<=eventLimit else { throw InputError.invalid("At most 256 expanded lyric events are supported") }
            }
        }
        if !zip(entries,entries.dropFirst()).allSatisfy({$0.time<=$1.time}) { diagnostics.append("Sorted out-of-order lyric events") }
        entries.sort { $0.time==$1.time ? $0.sourceLine<$1.sourceLine : $0.time<$1.time }
        var unique:[LyricEntry]=[]
        for entry in entries {
            if let last=unique.last,last.time==entry.time {
                guard last.text.utf8.elementsEqual(entry.text.utf8) else { throw InputError.invalid("Conflicting lyric events at one effective timestamp") }
                diagnostics.append("Deduplicated event at line \(entry.sourceLine)")
            } else { unique.append(entry) }
        }
        guard unique.contains(where:{!$0.text.isEmpty}) else { throw InputError.invalid("At least one nonempty lyric paragraph is required") }
        return .init(entries:unique,offsetMilliseconds:offset ?? 0,diagnostics:diagnostics)
    }
}
