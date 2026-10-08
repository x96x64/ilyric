import Foundation
import SpikeCore

public enum LyricsFormat: String, Sendable { case lrc, enhancedLRC = "enhanced-lrc", ttml }
public enum Highlighting: String, Sendable { case enabled, disabled }
/// Supplied absolute boundaries and original UTF-16 source ranges, not inferred words.
public struct TimedSegment: Equatable, Sendable {
    public let start, length: Int
    public let begin, end: Time
    public init(start:Int,length:Int,begin:Time,end:Time) {
        self.start=start;self.length=length;self.begin=begin;self.end=end
    }
    func shifted(_ offset:Time) -> TimedSegment {
        .init(start:start,length:length,begin:begin+offset,end:end+offset)
    }
}
public enum EnhancedLRCParser {
    public static let paragraphSegmentLimit=128, totalSegmentLimit=512
    public static func parse(_ data:Data) throws -> LocalLyrics {
        guard data.count<=LRCParser.byteLimit,var source=String(data:data,encoding:.utf8) else {
            throw InputError.invalid("Lyrics must be valid UTF-8 and no larger than 64 KiB")
        }
        if source.hasPrefix("\u{FEFF}") { source.removeFirst() }
        source=source.replacingOccurrences(of:"\r\n",with:"\n")
        struct Part { let text:String;let segments:[TimedSegment] }
        struct Row { let line:Int;var parts:[Part] }
        var rows:[Row]=[],lines:[String]=[],parent:Int?,total=0
        let tag=try NSRegularExpression(pattern:"<([^<>]*)>")
        func part(_ value:String,_ line:Int) throws -> Part {
            guard value.contains("<") || value.contains(">") else { return .init(text:value,segments:[]) }
            let ns=value as NSString,matches=tag.matches(in:value,range:NSRange(location:0,length:ns.length))
            guard matches.count>=2,matches.count<=paragraphSegmentLimit+1,matches.first!.range.location==0,
                  NSMaxRange(matches.last!.range)==ns.length,!value.contains("["),!value.contains("]") else {
                throw InputError.invalid("Timed line \(line) requires complete angle-bracket boundaries and an explicit terminal timestamp")
            }
            var text="",segments:[TimedSegment]=[]
            var previous:Time?
            for (i,match) in matches.enumerated() {
                let token=ns.substring(with:match.range(at:1))
                let time:Time
                do { time=try LRCParser.parse(Data(("["+token+"]x").utf8)).entries[0].time }
                catch { throw InputError.invalid("Invalid inline timestamp at line \(line)") }
                if let previous {
                    let begin=NSMaxRange(matches[i-1].range),end=match.range.location
                    let piece=ns.substring(with:NSRange(location:begin,length:end-begin))
                    guard !piece.isEmpty,!piece.contains("<"),!piece.contains(">"),previous<time else {
                        throw InputError.invalid("Positive, strictly increasing nonempty timed segments required at line \(line)")
                    }
                    segments.append(.init(start:text.utf16.count,length:piece.utf16.count,begin:previous,end:time))
                    text+=piece
                }
                previous=time
            }
            total+=segments.count
            guard total<=totalSegmentLimit else { throw InputError.invalid("At most 512 timed segments are supported") }
            return .init(text:text,segments:segments)
        }
        for (i,line) in source.components(separatedBy:"\n").enumerated() {
            if line.hasPrefix("|"),let p=parent {
                guard rows[p].parts.count<4 else { throw InputError.invalid("At most four supplied paragraph lines are supported") }
                let value=try part(String(line.dropFirst()),i+1)
                rows[p].parts.append(value);lines.append("|"+value.text);continue
            }
            if line.isEmpty { lines.append(line);continue }
            parent=nil
            var rest=line,prefix="",count=0
            while rest.hasPrefix("["),let end=rest.firstIndex(of:"]") {
                count+=1
                guard count<=LRCParser.eventLimit else { throw InputError.invalid("At most 64 timestamps are supported on one entry") }
                prefix+=rest[...end];rest=String(rest[rest.index(after:end)...])
            }
            if !prefix.isEmpty,!rest.isEmpty {
                let value=try part(rest,i+1)
                guard value.segments.isEmpty || count==1 else { throw InputError.invalid("Repeated paragraph timestamps with inline timing are ambiguous at line \(i+1)") }
                guard rows.count<LRCParser.eventLimit else { throw InputError.invalid("At most 64 expanded lyric events are supported") }
                rows.append(.init(line:i+1,parts:[value]));parent=rows.count-1
                lines.append(prefix+value.text)
            } else { lines.append(line) }
        }
        // Delegate ordinary metadata, offsets, repeated timestamps, gaps, limits and sorting.
        let base=try LRCParser.parse(Data(lines.joined(separator:"\n").utf8))
        var ranges:[Int:[TimedSegment]]=[:],duplicates:[Time:[TimedSegment]]=[:]
        for row in rows where row.parts.contains(where:{!$0.segments.isEmpty}) {
            guard row.parts.allSatisfy({!$0.segments.isEmpty}) else { throw InputError.invalid("Every physical line of a timed paragraph must supply timing at line \(row.line)") }
            var offset=0,segments:[TimedSegment]=[]
            for (i,p) in row.parts.enumerated() {
                if i>0 { offset+=1 }
                for s in p.segments {
                    segments.append(.init(start:s.start+offset,length:s.length,begin:s.begin+Time(base.offsetMilliseconds,1000),end:s.end+Time(base.offsetMilliseconds,1000)))
                }
                offset+=p.text.utf16.count
            }
            guard segments.count<=paragraphSegmentLimit,
                  zip(segments,segments.dropFirst()).allSatisfy({$0.end<=$1.begin}) else { throw InputError.invalid("Overlapping continuation timing or more than 128 paragraph segments at line \(row.line)") }
            let text=row.parts.map(\.text).joined(separator:"\n")
            var boundaries=Set([0]),index=0
            for c in text { index+=String(c).utf16.count;boundaries.insert(index) }
            guard segments.allSatisfy({boundaries.contains($0.start) && boundaries.contains($0.start+$0.length)}) else { throw InputError.invalid("Timing boundary splits an extended grapheme cluster at line \(row.line)") }
            ranges[row.line]=segments
        }
        // Reparse each original row's paragraph timestamp to audit duplicates removed by LRC.
        for row in rows {
            let header=lines[row.line-1]
            let times=try LRCParser.parse(Data(header.utf8)).entries.map { $0.time+Time(base.offsetMilliseconds,1000) }
            let segments=ranges[row.line] ?? []
            for time in times {
                if let previous=duplicates[time],previous != segments { throw InputError.invalid("Conflicting inline timing at a duplicate paragraph timestamp") }
                duplicates[time]=segments
            }
        }
        let entries=base.entries.map { LyricEntry(time:$0.time,text:$0.text,sourceLine:$0.sourceLine,suppliedBreaks:$0.suppliedBreaks,segments:ranges[$0.sourceLine] ?? []) }
        let result=LocalLyrics(entries:entries,offsetMilliseconds:base.offsetMilliseconds,diagnostics:base.diagnostics)
        try result.validateSegments();return result
    }
}
public enum LyricsParser {
    public static func parse(_ data:Data,format:LyricsFormat) throws -> LocalLyrics {
        switch format {
        case .lrc: return try LRCParser.parse(data)
        case .enhancedLRC: return try EnhancedLRCParser.parse(data)
        case .ttml: return try TTMLParser.parse(data)
        }
    }
}
public extension LocalLyrics {
    func validateSegments(audioEnd:Time = Time(600)) throws {
        for (i,e) in entries.enumerated() {
            if let explicit=e.intervalEnd {
                guard e.time<explicit,explicit<=audioEnd,(i+1==entries.count || explicit<=entries[i+1].time) else {
                    throw InputError.invalid("Explicit paragraph interval overlaps or exceeds the audio endpoint")
                }
            }
            let end=min(e.intervalEnd ?? audioEnd,i+1<entries.count ? min(entries[i+1].time,audioEnd) : audioEnd)
            guard e.segments.allSatisfy({$0.begin>=e.time && $0.begin<$0.end && $0.end<=end}) else {
                throw InputError.invalid("Segment outside its paragraph interval or audio endpoint at line \(e.sourceLine)")
            }
        }
    }
}
