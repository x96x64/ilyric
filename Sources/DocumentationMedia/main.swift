import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import LyricsInputCore
import LyricsInputMac
import LyricsSliceCore
import SpikeCore

// Renders the README demonstration image from fixtures/demo: "The Star" by Jane Taylor (1806), in the public domain,
// with synthetic evenly spaced word timing and silent audio. Controls and the placeholder artwork use SF Symbols,
// resolved at runtime on the rendering Mac, as decided in docs/sf-symbols-rights-assessment.md.
// Usage: DocumentationMedia LYRICS.txt OUTPUT.png

func stamp(_ t: Double) -> String { String(format:"%.3fs",t) }
func escape(_ s: String) -> String { s.replacingOccurrences(of:"&",with:"&amp;").replacingOccurrences(of:"<",with:"&lt;") }
/// Each line lasts 2.6 s with evenly timed words; an instrumental gap of 7 s follows the second line, so that every
/// shown state occurs before the title marquee first moves (8.11 s).
func timedLyrics(_ raw: String) throws -> (ttml: String, end: Double) {
    let stanzas=raw.components(separatedBy:"\n\n").map { $0.split(separator:"\n").map { $0.trimmingCharacters(in:.whitespaces) }.filter { !$0.isEmpty } }.filter { !$0.isEmpty }
    var paragraphs=[String](),time=1.0
    for (n,line) in stanzas.joined().enumerated() {
        if n==2 { time+=7 }
        let words=line.split(separator:" ").map(String.init),step=2.6/Double(words.count)
        let spans=words.enumerated().map { i,w in
            "<span begin=\"\(stamp(Double(i)*step))\" end=\"\(stamp(Double(i+1)*step))\">\(escape(w))\(i<words.count-1 ? " " : "")</span>"
        }.joined()
        paragraphs.append("<p begin=\"\(stamp(time))\" end=\"\(stamp(time+2.6))\">\(spans)</p>")
        time+=2.8
    }
    return ("<tt xmlns=\"http://www.w3.org/ns/ttml\" xml:space=\"preserve\"><body><div>"+paragraphs.joined()+"</div></body></tt>\n",time)
}

do {
    guard CommandLine.arguments.count==3 else { throw InputError.invalid("Usage: DocumentationMedia LYRICS.txt OUTPUT.png") }
    let (ttml,time)=try timedLyrics(String(contentsOfFile:CommandLine.arguments[1],encoding:.utf8))
    let lyrics=try LyricsParser.parse(Data(ttml.utf8),format:.ttml)
    let audio=LocalAudio(samples:[Int16](repeating:0,count:Int((time+3)*48_000)),sourceRate:48_000,sourceChannels:1,sourceFormat:0)
    var presentation=LocalPresentation(background:.fitted,icons:.systemSymbols,minimumGap:Time(4),
        focusLead:LocalPresentation.measuredMotion.focusLead,stagger:LocalPresentation.measuredMotion.stagger,
        marquee:.measured,wordMotion:.measured,fillLead:LocalPresentation.measuredFillLead,hideControls:LocalPresentation.measuredControlHide)
    presentation.holdsFinishedLine=true;presentation.collapsesGaps=true
    let scene=try LocalScene(lyrics:lyrics,audio:audio,artwork:PlaceholderArtwork.image(),presentation:presentation,
                             title:"Twinkle, Twinkle, Little Star",artist:"Jane Taylor")
    // Controls visible during the first line, word fill of the second line, and the instrumental gap, all before
    // the title marquee's delay so that the title rests at its initial position.
    let times=[Time(23,10),Time(47,10),Time(76,10)]
    // Frames contain the native 1179 × 2556 screen pillarboxed in 1080 × 1920; only the screen is kept.
    let screenWidth=1920.0*1179/2556,inset=(1080-screenWidth)/2
    let height=960,width=Int((screenWidth*Double(height)/1920).rounded()),gap=32,radius=44.0
    let sheet=CGContext(data:nil,width:3*width+2*gap,height:height,bitsPerComponent:8,bytesPerRow:(3*width+2*gap)*4,
                        space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    sheet.interpolationQuality = .high
    for (k,t) in times.enumerated() {
        guard let screen=try scene.renderer.frame(t).cropping(to:CGRect(x:inset.rounded(.up),y:0,width:screenWidth.rounded(.down),height:1920)) else {
            throw InputError.invalid("Frame cropping failed")
        }
        let rect=CGRect(x:k*(width+gap),y:0,width:width,height:height)
        sheet.saveGState()
        sheet.addPath(CGPath(roundedRect:rect,cornerWidth:radius,cornerHeight:radius,transform:nil));sheet.clip()
        sheet.draw(screen,in:rect);sheet.restoreGState()
    }
    let url=URL(fileURLWithPath:CommandLine.arguments[2]) as CFURL
    guard let image=sheet.makeImage(),let destination=CGImageDestinationCreateWithURL(url,UTType.png.identifier as CFString,1,nil) else { throw InputError.invalid("Image encoding failed") }
    CGImageDestinationAddImage(destination,image,nil)
    guard CGImageDestinationFinalize(destination) else { throw InputError.invalid("Image writing failed") }
} catch {
    FileHandle.standardError.write(Data("DocumentationMedia: \(error)\n".utf8));exit(1)
}
