import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import SpikeCore

/// Bounded TTML2 content/timing import, not a general TTML presentation processor.
public enum TTMLParser {
    public static func parse(_ data: Data) throws -> LocalLyrics {
        guard data.count<=LRCParser.byteLimit, let source=String(data:data,encoding:.utf8) else {
            throw InputError.invalid("TTML must be UTF-8 and no larger than 64 KiB")
        }
        guard !source.contains("<!DOCTYPE"),!source.contains("<!ENTITY") else {
            throw InputError.invalid("TTML document types and entity declarations are forbidden")
        }
        if let declaration=source.range(of:"<\\?xml\\s[^?]*\\?>",options:.regularExpression) {
            let value=String(source[declaration])
            guard value.range(of:"version\\s*=\\s*['\"]1\\.0['\"]",options:.regularExpression) != nil,
                  value.range(of:"encoding\\s*=",options:.regularExpression)==nil || value.range(of:"encoding\\s*=\\s*['\"][Uu][Tt][Ff]-8['\"]",options:.regularExpression) != nil else {
                throw InputError.invalid("Only XML 1.0 with UTF-8 encoding is supported")
            }
        }
        let delegate=TTMLReader(),parser=XMLParser(data:data)
        parser.shouldProcessNamespaces=true;parser.shouldReportNamespacePrefixes=true
        parser.shouldResolveExternalEntities=false;parser.externalEntityResolvingPolicy = .never
        parser.delegate=delegate
        let parsed=parser.parse()
        if let error=delegate.failure { throw error }
        guard parsed,let root=delegate.root,delegate.stack.isEmpty else { throw InputError.invalid("Malformed TTML XML") }
        return try delegate.convert(root)
    }
    public static func time(_ value:String) throws -> Time {
        func decimal(_ text:String) throws -> (Int64,Int64) {
            let pieces=text.split(separator:".",omittingEmptySubsequences:false)
            guard pieces.count<=2,!pieces[0].isEmpty,pieces[0].count<=9,
                  pieces.allSatisfy({!$0.isEmpty && $0.utf8.allSatisfy({(48...57).contains($0)})}),
                  pieces.count==1 || pieces[1].count<=6 else { throw InputError.invalid("Unsupported TTML time precision or syntax") }
            var scale:Int64=1
            if pieces.count==2 {for _ in pieces[1] {scale*=10}}
            return (Int64(pieces[0])!*scale+(pieces.count==1 ? 0:Int64(pieces[1])!),scale)
        }
        let result:Time
        if value.contains(":") {
            let parts=value.split(separator:":",omittingEmptySubsequences:false)
            guard parts.count==3,parts[0].count>=2,parts[1].count==2,parts[2].split(separator:".").first?.count==2 else { throw InputError.invalid("Unsupported TTML clock time") }
            let (h,hd)=try decimal(String(parts[0])),(m,md)=try decimal(String(parts[1])),(s,sd)=try decimal(String(parts[2]))
            guard hd==1,md==1,m<60,s<60*sd else { throw InputError.invalid("TTML clock fields out of range") }
            result=Time(h*3600+m*60)+Time(s,sd)
        } else {
            let units:[(String,Int64,Int64)]=[("ms",1,1000),("h",3600,1),("m",60,1),("s",1,1)]
            guard let unit=units.first(where:{value.hasSuffix($0.0)}) else { throw InputError.invalid("Unsupported TTML time unit") }
            let (n,d)=try decimal(String(value.dropLast(unit.0.count)))
            result=Time(n*unit.1,d*unit.2)
        }
        guard result>=Time(0),result<=Time(600) else { throw InputError.invalid("TTML time outside 0–600 seconds") }
        return result
    }
}

private final class TTMLNode {
    enum Part { case text(String), node(TTMLNode) }
    let name:String,attributes:[String:String],line:Int
    var parts:[Part]=[]
    init(_ name:String,_ attributes:[String:String],_ line:Int) { self.name=name;self.attributes=attributes;self.line=line }
    var children:[TTMLNode] { parts.compactMap { if case .node(let n)=$0 {return n};return nil } }
}
private final class TTMLReader: NSObject, XMLParserDelegate {
    static let tt="http://www.w3.org/ns/ttml",xml="http://www.w3.org/XML/1998/namespace",parameter="http://www.w3.org/ns/ttml#parameter"
    var root:TTMLNode?,stack:[TTMLNode]=[],failure:InputError?
    var namespaces:[String:[String]]=["xml":[xml]],elements=0,textUnits=0,ids=Set<String>()
    func fail(_ parser:XMLParser,_ message:String) { if failure==nil {failure = .invalid(message)};parser.abortParsing() }
    func parser(_ parser:XMLParser,didStartMappingPrefix prefix:String,toURI uri:String) { namespaces[prefix,default:[]].append(uri) }
    func parser(_ parser:XMLParser,didEndMappingPrefix prefix:String) { _=namespaces[prefix]?.popLast() }
    func parser(_ parser:XMLParser,didStartElement name:String,namespaceURI:String?,qualifiedName:String?,attributes:[String:String]) {
        guard failure==nil else {return}
        elements+=1
        guard namespaceURI==Self.tt,elements<=1024,stack.count<6 else { fail(parser,"Unsupported TTML namespace or XML resource limit");return }
        let parent=stack.last?.name
        let allowed:[String:[String]]=["tt":["body"],"body":["div"],"div":["p"],"p":["span","br"],"span":["br"]]
        guard parent==nil ? name=="tt" && root==nil : (allowed[parent!] ?? []).contains(name) else { fail(parser,"Unsupported TTML element structure");return }
        var clean:[String:String]=[:]
        for (key,value) in attributes {
            let parts=key.split(separator:":",omittingEmptySubsequences:false)
            let uri=parts.count==1 ? "" : namespaces[String(parts[0])]?.last ?? "?"
            let local=String(parts.last!)
            let canonical:String
            if uri==Self.xml && ["space","id","lang"].contains(local) { canonical="xml:"+local }
            else if uri==Self.parameter && name=="tt" && local=="timeBase" {canonical="ttp:timeBase"}
            else if uri.isEmpty && name != "tt" && name != "br" && ["begin","end","dur","timeContainer"].contains(local) {canonical=local}
            else { fail(parser,"Unsupported TTML attribute");return }
            guard clean[canonical]==nil else { fail(parser,"Duplicate TTML attribute");return }
            clean[canonical]=value
        }
        if let space=clean["xml:space"],space != "preserve" { fail(parser,"TTML requires preserved whitespace");return }
        if parent==nil && clean["xml:space"] != "preserve" { fail(parser,"TTML root requires xml:space=preserve");return }
        if let base=clean["ttp:timeBase"],base != "media" { fail(parser,"Only TTML media time is supported");return }
        if let container=clean["timeContainer"],container != "par" { fail(parser,"Only parallel TTML containers are supported");return }
        if let id=clean["xml:id"] {
            guard id.count<=80,id.range(of:"^[A-Za-z_][A-Za-z0-9_.-]*$",options:.regularExpression) != nil,ids.insert(id).inserted else {fail(parser,"Unsupported or duplicate XML ID");return}
        }
        if let lang=clean["xml:lang"],lang.count>80 || lang.range(of:"^[A-Za-z0-9-]*$",options:.regularExpression)==nil {fail(parser,"Unsupported XML language identifier");return}
        let node=TTMLNode(name,clean,parser.lineNumber)
        if let last=stack.last {last.parts.append(.node(node))} else {root=node}
        stack.append(node)
    }
    func parser(_ parser:XMLParser,didEndElement:String,namespaceURI:String?,qualifiedName:String?) { if failure==nil {_=stack.popLast()} }
    func parser(_ parser:XMLParser,foundCharacters text:String) {
        guard failure==nil,!text.isEmpty else {return}
        textUnits+=text.utf16.count
        guard textUnits<=65536 else {fail(parser,"TTML decoded text limit exceeded");return}
        guard let node=stack.last else {return}
        if ["p","span"].contains(node.name) {
            guard !text.unicodeScalars.contains(where:{$0.value<32 || $0.value==127}) else {fail(parser,"Use br for TTML lyric line breaks; text controls are unsupported");return}
            node.parts.append(.text(text))
        } else if !text.allSatisfy({$0==" " || $0=="\n" || $0=="\r" || $0=="\t"}) || node.name=="br" {
            fail(parser,"Text outside supported TTML paragraphs")
        }
    }
    func parser(_ parser:XMLParser,foundCDATA data:Data) {
        guard let text=String(data:data,encoding:.utf8) else {fail(parser,"Invalid UTF-8 CDATA");return}
        self.parser(parser,foundCharacters:text)
    }
    func parser(_ parser:XMLParser,foundProcessingInstructionWithTarget:String,data:String?) {fail(parser,"TTML processing instructions are unsupported")}
    func parser(_ parser:XMLParser,resolveExternalEntityName:String,systemID:String?) -> Data? {fail(parser,"External XML resources are forbidden");return nil}
    func convert(_ root:TTMLNode) throws -> LocalLyrics {
        func single(_ node:TTMLNode,_ name:String) throws -> TTMLNode {
            guard node.children.count==1,node.children[0].name==name else {throw InputError.invalid("Exactly one TTML \(name) is required")}
            return node.children[0]
        }
        func interval(_ node:TTMLNode,_ parent:(Time,Time),required:Bool) throws -> (Time,Time) {
            let a=node.attributes
            guard !(a["end"] != nil && a["dur"] != nil),!required || (a["begin"] != nil && (a["end"] != nil || a["dur"] != nil)) else {
                throw InputError.invalid("TTML p/span requires begin and exactly one end or dur")
            }
            let begin=try parent.0+(a["begin"].map(TTMLParser.time) ?? Time(0))
            let end:Time
            if let value=a["end"] {end=try parent.0+TTMLParser.time(value)}
            else if let value=a["dur"] {end=try begin+TTMLParser.time(value)}
            else {end=parent.1}
            guard begin>=parent.0,begin<end,end<=parent.1 else {throw InputError.invalid("TTML interval is empty or outside its parent")}
            return (begin,end)
        }
        func text(_ node:TTMLNode) throws -> String {
            try node.parts.map { part -> String in
                switch part {
                case .text(let value):return value
                case .node(let child):
                    guard child.name=="br",child.parts.isEmpty else {throw InputError.invalid("Unsupported nested TTML text")}
                    return "\n"
                }
            }.joined()
        }
        let body=try single(root,"body"),div=try single(body,"div")
        let bounds=try interval(div,interval(body,(Time(0),Time(600)),required:false),required:false)
        guard (1...64).contains(div.children.count) else {throw InputError.invalid("TTML requires 1–64 paragraphs or gaps")}
        var entries:[LyricEntry]=[],total=0
        for p in div.children {
            let range=try interval(p,bounds,required:true)
            if let last=entries.last {guard last.intervalEnd!<=range.0 else {throw InputError.invalid("Overlapping or out-of-order TTML paragraphs")}}
            let spans=p.children.filter{$0.name=="span"}
            var value="",segments:[TimedSegment]=[]
            if spans.isEmpty {value=try text(p)}
            else {
                guard spans.count<=128 else {throw InputError.invalid("At most 128 TTML spans per paragraph")}
                for part in p.parts {
                    guard case .node(let node)=part else {throw InputError.invalid("Every text unit in a timed TTML paragraph must belong to a timed span")}
                    if node.name=="br" {value+="\n";continue}
                    let piece=try text(node),timing=try interval(node,range,required:true)
                    guard !piece.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else {throw InputError.invalid("Empty TTML timed span")}
                    if let previous=segments.last {guard previous.end<=timing.0 else {throw InputError.invalid("Overlapping or out-of-order TTML spans")}}
                    segments.append(.init(start:value.utf16.count,length:piece.utf16.count,begin:timing.0,end:timing.1));value+=piece
                }
                var boundaries=Set([0]),i=0
                for c in value {i+=String(c).utf16.count;boundaries.insert(i)}
                guard segments.allSatisfy({boundaries.contains($0.start) && boundaries.contains($0.start+$0.length)}) else {throw InputError.invalid("TTML span boundary splits an extended grapheme")}
            }
            total+=segments.count
            guard total<=512,value.utf16.count<500,value.components(separatedBy:"\n").count<=4,
                  value.isEmpty || value.components(separatedBy:"\n").allSatisfy({!$0.trimmingCharacters(in:.whitespaces).isEmpty}) else {throw InputError.invalid("TTML text or timing resource limit")}
            entries.append(.init(time:range.0,text:value,sourceLine:p.line,suppliedBreaks:value.contains("\n"),segments:segments,intervalEnd:range.1))
        }
        guard entries.contains(where:{!$0.text.isEmpty}) else {throw InputError.invalid("TTML requires a nonempty lyric paragraph")}
        let result=LocalLyrics(entries:entries,offsetMilliseconds:0,diagnostics:[])
        try result.validateSegments();return result
    }
}
