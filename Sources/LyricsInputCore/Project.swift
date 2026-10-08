import Foundation
import CoreFoundation
import SpikeCore

/// Experimental versioned settings. Paths are resolved once, independently of rendering.
public struct ProjectVisibility: Equatable, Sendable {
    public let artwork, metadata, progress, transport, volume, bottom, handle, translation: Bool
    public let sing: String
}
public struct ExperimentalProject: Equatable, Sendable {
    public let version: Int
    public let lyricsFormat: LyricsFormat
    public let highlighting: Highlighting
    public let audio, lyrics: URL
    public let artwork: URL?
    public let title, artist: String
    public let offsetMilliseconds: Int64
    public let visibility: ProjectVisibility
    public static let byteLimit = 65_536

    public static func parse(_ data: Data, at url: URL) throws -> ExperimentalProject {
        guard data.count<=byteLimit, !data.starts(with:[0xef,0xbb,0xbf]), String(data:data,encoding:.utf8) != nil else {
            throw InputError.invalid("Project must be UTF-8 JSON no larger than 64 KiB")
        }
        let json: Any
        do { json=try JSONSerialization.jsonObject(with:data) }
        catch { throw InputError.invalid("Project is not valid JSON") }
        var scan=UniqueJSON(data:data);try scan.value(depth:0);scan.whitespace()
        guard scan.index==scan.bytes.count else { throw InputError.invalid("Invalid project JSON structure") }
        let root=try Object(json,"project",["version","inputs","metadata","timing","output","visibility"])
        let version=try root.integer("version",required:true)!
        guard [1,2,3].contains(version) else { throw InputError.invalid("Unsupported experimental project version; expected 1, 2, or 3") }
        let input=try root.object("inputs",required:true,allowed:version==1 ? ["audio","lyrics","artwork"] : ["audio","lyrics","artwork","lyricsFormat"])
        let formatValue=try input.string("lyricsFormat",required:version>=2) ?? "lrc"
        guard let format=LyricsFormat(rawValue:formatValue),version>=3 || format != .ttml else { throw InputError.invalid("lyricsFormat must be lrc or enhanced-lrc; ttml requires version 3") }
        let base=url.standardizedFileURL.deletingLastPathComponent()
        func path(_ value:String) throws -> URL {
            guard !value.isEmpty,value.utf8.count<=4096,!value.unicodeScalars.contains(where:{$0.value<32 || $0.value==127}) else { throw InputError.invalid("Input paths must be nonempty local paths within 4096 bytes") }
            // No shell, environment-variable, tilde, URL, or network expansion.
            guard !value.contains("://") else { throw InputError.invalid("Use filesystem paths, not URLs") }
            return URL(fileURLWithPath:value,relativeTo:base).standardizedFileURL
        }
        let audio=try path(input.string("audio",required:true)!),lyrics=try path(input.string("lyrics",required:true)!)
        let artwork=try input.string("artwork").map(path)
        let metadata=try root.object("metadata",allowed:["title","artist"])
        let title=try metadata.string("title") ?? "Local Lyrics",artist=try metadata.string("artist") ?? "Supplied Recording"
        for text in [title,artist] {
            guard !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,text.utf16.count<=80,
                  !text.unicodeScalars.contains(where:{$0.value<32 || $0.value==127}) else { throw InputError.invalid("Metadata must contain 1–80 UTF-16 units without control characters") }
        }
        let timing=try root.object("timing",allowed:version==1 ? ["offsetMilliseconds","durationPolicy"] : ["offsetMilliseconds","durationPolicy","highlighting"])
        let highlightingValue=try timing.string("highlighting") ?? "enabled"
        guard let highlighting=Highlighting(rawValue:highlightingValue) else { throw InputError.invalid("highlighting must be enabled or disabled") }
        guard format != .lrc || timing.values["highlighting"] == nil else { throw InputError.invalid("highlighting requires enhanced-lrc or ttml input") }
        let offset=try timing.integer("offsetMilliseconds") ?? 0
        guard (-600_000...600_000).contains(offset) else { throw InputError.invalid("Project lyric offset must be within ±600000 milliseconds") }
        guard try timing.string("durationPolicy") ?? "audio-pad-frame" == "audio-pad-frame" else { throw InputError.invalid("Only audio-pad-frame duration policy is supported") }
        let output=try root.object("output",allowed:["width","height","fps","videoCodec","audioCodec","delivery"])
        for (key,value) in [("width",Int64(1080)),("height",1920),("fps",60)] {
            guard try output.integer(key) ?? value == value else { throw InputError.invalid("Unsupported output \(key); expected \(value)") }
        }
        for (key,value) in [("videoCodec","h264"),("audioCodec","aac"),("delivery","contain")] {
            guard try output.string(key) ?? value == value else { throw InputError.invalid("Unsupported output \(key); expected \(value)") }
        }
        let v=try root.object("visibility",allowed:["artwork","metadata","progress","transport","volume","bottom","handle","translation","sing"])
        let sing=try v.string("sing") ?? "hidden"
        guard ["hidden","compact","expanded"].contains(sing) else { throw InputError.invalid("Sing control visibility must be hidden, compact, or expanded; no Sing functionality is implied") }
        return try .init(version:Int(version),lyricsFormat:format,highlighting:highlighting,audio:audio,lyrics:lyrics,artwork:artwork,title:title,artist:artist,offsetMilliseconds:offset,
            visibility:.init(artwork:v.boolean("artwork") ?? true,metadata:v.boolean("metadata") ?? true,
                progress:v.boolean("progress") ?? true,transport:v.boolean("transport") ?? true,
                volume:v.boolean("volume") ?? true,bottom:v.boolean("bottom") ?? true,
                handle:v.boolean("handle") ?? true,translation:v.boolean("translation") ?? false,sing:sing))
    }
}

private struct Object {
    let values:[String:Any],name:String
    init(_ value:Any,_ name:String,_ allowed:Set<String>) throws {
        guard let values=value as? [String:Any] else { throw InputError.invalid("\(name) must be an object") }
        if let key=Set(values.keys).subtracting(allowed).sorted().first { throw InputError.invalid("Unknown field \(name).\(key)") }
        self.values=values;self.name=name
    }
    func object(_ key:String,required:Bool=false,allowed:Set<String>) throws -> Object {
        if let value=values[key] { return try Object(value,name+"."+key,allowed) }
        guard !required else { throw InputError.invalid("Missing required field \(name).\(key)") }
        return try Object([String:Any](),name+"."+key,allowed)
    }
    func string(_ key:String,required:Bool=false) throws -> String? {
        guard let value=values[key] else {
            if required { throw InputError.invalid("Missing required field \(name).\(key)") };return nil
        }
        guard let text=value as? String else { throw InputError.invalid("\(name).\(key) must be a string") };return text
    }
    func integer(_ key:String,required:Bool=false) throws -> Int64? {
        guard let value=values[key] else {
            if required { throw InputError.invalid("Missing required field \(name).\(key)") };return nil
        }
        guard let n=value as? NSNumber,CFGetTypeID(n) != CFBooleanGetTypeID(),
              !["f","d"].contains(String(cString:n.objCType)),let integer=Int64(n.stringValue) else { throw InputError.invalid("\(name).\(key) must be an integer") }
        return integer
    }
    func boolean(_ key:String) throws -> Bool? {
        guard let value=values[key] else { return nil }
        guard let n=value as? NSNumber,CFGetTypeID(n)==CFBooleanGetTypeID() else { throw InputError.invalid("\(name).\(key) must be a Boolean") };return n.boolValue
    }
}

/// Foundation validates syntax first. This bounded pass rejects duplicate decoded keys,
/// including escaped aliases, rather than relying on a decoder's duplicate-key preference.
private struct UniqueJSON {
    let bytes:[UInt8];var index=0
    init(data:Data) { bytes=Array(data) }
    mutating func whitespace() { while index<bytes.count && [9,10,13,32].contains(bytes[index]) { index+=1 } }
    mutating func consume(_ byte:UInt8) -> Bool {
        whitespace();guard index<bytes.count,bytes[index]==byte else { return false };index+=1;return true
    }
    mutating func require(_ byte:UInt8) throws {
        guard consume(byte) else { throw InputError.invalid("Invalid strict JSON structure") }
    }
    mutating func string() throws -> String {
        whitespace();let start=index;try require(34)
        while index<bytes.count {
            if bytes[index]==92 { index+=2;continue }
            if bytes[index]==34 {
                index+=1
                do { return try JSONDecoder().decode(String.self,from:Data(bytes[start..<index])) }
                catch { throw InputError.invalid("Invalid JSON string") }
            }
            index+=1
        }
        throw InputError.invalid("Invalid JSON string")
    }
    mutating func value(depth:Int) throws {
        guard depth<=16 else { throw InputError.invalid("Project nesting exceeds 16 levels") }
        whitespace();guard index<bytes.count else { throw InputError.invalid("Invalid JSON value") }
        switch bytes[index] {
        case 123:
            index+=1;var keys=Set<String>()
            if consume(125) { return }
            while true {
                let key=try string()
                guard keys.insert(key).inserted else { throw InputError.invalid("Duplicate JSON object field") }
                try require(58);try value(depth:depth+1)
                if consume(125) { return };try require(44)
            }
        case 91:
            index+=1;if consume(93) { return }
            while true { try value(depth:depth+1);if consume(93) { return };try require(44) }
        case 34: _=try string()
        default:
            let start=index
            while index<bytes.count && ![9,10,13,32,44,93,125].contains(bytes[index]) { index+=1 }
            let token=String(decoding:bytes[start..<index],as:UTF8.self)
            guard ["true","false","null"].contains(token) || token.range(of:"^-?(0|[1-9][0-9]*)(\\.[0-9]+)?([eE][+-]?[0-9]+)?$",options:.regularExpression) != nil else {
                throw InputError.invalid("Invalid strict JSON value")
            }
        }
    }
}

public extension LocalLyrics {
    func applyingProjectOffset(_ milliseconds:Int64) throws -> LocalLyrics {
        guard (-600_000...600_000).contains(milliseconds) else { throw InputError.invalid("Project lyric offset out of range") }
        let shifted=entries.map { LyricEntry(time:$0.time+Time(milliseconds,1000),text:$0.text,sourceLine:$0.sourceLine,suppliedBreaks:$0.suppliedBreaks,segments:$0.segments.map { $0.shifted(Time(milliseconds,1000)) },intervalEnd:$0.intervalEnd.map { $0+Time(milliseconds,1000) }) }
        guard shifted.allSatisfy({$0.time>=Time(0) && $0.time<=Time(600) && ($0.intervalEnd.map { $0<=Time(600) } ?? true)}) else { throw InputError.invalid("Combined lyric offset places an event outside 0–600 seconds") }
        let result=LocalLyrics(entries:shifted,offsetMilliseconds:offsetMilliseconds+milliseconds,diagnostics:diagnostics)
        try result.validateSegments();return result
    }
}
