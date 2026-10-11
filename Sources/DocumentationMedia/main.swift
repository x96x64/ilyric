import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import LyricsInputCore
import LyricsInputMac
import LyricsSliceCore
import SpikeCore

// Renders the README demonstration image from original synthetic material: Lorem ipsum text (from Cicero, in the
// public domain), silent audio, iLyric's placeholder artwork, and the original control icons.
// Usage: DocumentationMedia OUTPUT.png

let lines:[(text:String,background:String?)]=[
    ("Lorem ipsum dolor sit amet",nil),("Consectetur adipiscing elit",nil),
    ("Sed do eiusmod tempor",nil),("Incididunt ut labore",nil),
    ("Ut enim ad minim veniam",nil),("Quis nostrud exercitation",nil),
    ("Ullamco laboris nisi",nil),("Ut aliquip ex ea commodo","ex ea commodo"),
    ("Duis aute irure dolor",nil),("In reprehenderit in voluptate",nil),
    ("Velit esse cillum dolore",nil),("Eu fugiat nulla pariatur",nil)]
// Each line lasts 2.6 s with evenly timed words; an instrumental gap follows the eighth line.
func stamp(_ t: Double) -> String { String(format:"%.3fs",t) }
var paragraphs=[String](),time=1.0
for (i,line) in lines.enumerated() {
    if i==8 { time+=7 }
    let words=line.text.split(separator:" ").map(String.init),step=2.6/Double(words.count)
    let spans=words.enumerated().map { k,w in
        "<span begin=\"\(stamp(Double(k)*step))\" end=\"\(stamp(Double(k+1)*step))\">\(w)\(k<words.count-1 ? " " : "")</span>"
    }.joined()
    let background=line.background.map { "<span ttm:role=\"x-bg\">\($0)</span>" } ?? ""
    paragraphs.append("<p begin=\"\(stamp(time))\" end=\"\(stamp(time+2.6))\">\(spans)\(background)</p>")
    time+=2.8
}
let ttml="<tt xmlns=\"http://www.w3.org/ns/ttml\" xmlns:ttm=\"http://www.w3.org/ns/ttml#metadata\" xml:space=\"preserve\"><body><div>"+paragraphs.joined()+"</div></body></tt>\n"

do {
    guard CommandLine.arguments.count==2 else { throw InputError.invalid("Usage: DocumentationMedia OUTPUT.png") }
    let lyrics=try LyricsParser.parse(Data(ttml.utf8),format:.ttml)
    let audio=LocalAudio(samples:[Int16](repeating:0,count:Int((time+3)*48_000)),sourceRate:48_000,sourceChannels:1,sourceFormat:0)
    var presentation=LocalPresentation(background:.fitted,icons:.original,minimumGap:Time(4),
        focusLead:LocalPresentation.measuredMotion.focusLead,stagger:LocalPresentation.measuredMotion.stagger,
        marquee:.measured,wordMotion:.measured,fillLead:LocalPresentation.measuredFillLead,hideControls:LocalPresentation.measuredControlHide)
    presentation.holdsFinishedLine=true;presentation.collapsesGaps=true
    let scene=try LocalScene(lyrics:lyrics,audio:audio,artwork:PlaceholderArtwork.image(),presentation:presentation,
                             title:"Lorem Ipsum",artist:"Dolor Sit Amet")
    // Controls visible during the first line, word fill with a background vocal, and the instrumental gap.
    let times=[Time(23,10),Time(2107,100),Time(2780,100)]
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
    let url=URL(fileURLWithPath:CommandLine.arguments[1]) as CFURL
    guard let image=sheet.makeImage(),let destination=CGImageDestinationCreateWithURL(url,UTType.png.identifier as CFString,1,nil) else { throw InputError.invalid("Image encoding failed") }
    CGImageDestinationAddImage(destination,image,nil)
    guard CGImageDestinationFinalize(destination) else { throw InputError.invalid("Image writing failed") }
} catch {
    FileHandle.standardError.write(Data("DocumentationMedia: \(error)\n".utf8));exit(1)
}
