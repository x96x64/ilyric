import Foundation
import ImageIO
import CoreGraphics
import LyricsInputCore

public enum LocalFile {
    public static func boundedData(_ url: URL, limit: Int, label: String) throws -> Data {
        guard let size=try? url.resourceValues(forKeys:[.fileSizeKey,.isRegularFileKey]),size.isRegularFile==true,
              let count=size.fileSize,count<=limit,FileManager.default.isReadableFile(atPath:url.path) else {
            throw InputError.invalid("\(label) is missing, inaccessible, not a regular file, or exceeds its byte limit")
        }
        do {
            let handle=try FileHandle(forReadingFrom:url);defer { try? handle.close() }
            let data=try handle.read(upToCount:limit+1) ?? Data()
            guard data.count<=limit else { throw InputError.invalid("\(label) exceeds its byte limit") }
            return data
        } catch let error as InputError { throw error }
        catch { throw InputError.invalid("\(label) could not be read") }
    }
}
public struct ArtworkInfo: Equatable {
    public let width, height: Int
    public let reportedColorProfile: Bool
}
public struct LocalArtwork {
    public let image: CGImage
    public let info: ArtworkInfo
    public static func decode(_ url: URL) throws -> LocalArtwork {
        let data=try LocalFile.boundedData(url,limit:16*1024*1024,label:"Artwork")
        guard let source=CGImageSourceCreateWithData(data as CFData,[kCGImageSourceShouldCache:false] as CFDictionary),
              CGImageSourceGetCount(source)==1,
              let properties=CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],
              let width=properties[kCGImagePropertyPixelWidth] as? Int,
              let height=properties[kCGImagePropertyPixelHeight] as? Int,
              (1...4096).contains(width),(1...4096).contains(height),width*height<=8_388_608 else {
            throw InputError.invalid("Artwork must be one decodable image within 4096 pixels per side and 8 megapixels")
        }
        // ImageIO applies EXIF orientation and bounds decode to 1024 pixels. Embedded
        // color space is honored by drawing into the explicit sRGB destination.
        let options:[CFString:Any]=[kCGImageSourceCreateThumbnailFromImageAlways:true,
            kCGImageSourceCreateThumbnailWithTransform:true,kCGImageSourceThumbnailMaxPixelSize:1024,
            kCGImageSourceShouldCacheImmediately:true]
        guard let decoded=CGImageSourceCreateThumbnailAtIndex(source,0,options as CFDictionary),
              let c=CGContext(data:nil,width:decoded.width,height:decoded.height,bitsPerComponent:8,bytesPerRow:decoded.width*4,
                space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw InputError.invalid("Artwork decoding failed")
        }
        c.draw(decoded,in:CGRect(x:0,y:0,width:decoded.width,height:decoded.height))
        guard let image=c.makeImage() else { throw InputError.invalid("Artwork color conversion failed") }
        return .init(image:image,info:.init(width:width,height:height,reportedColorProfile:properties[kCGImagePropertyProfileName] != nil))
    }
}
/// Full preparation occurs before export, including hidden assets and paragraph bounds.
public struct PreparedProject {
    public let project: ExperimentalProject
    public let scene: LocalScene
    public let artworkInfo: ArtworkInfo?
    public static func load(_ url: URL) async throws -> PreparedProject {
        let project=try ExperimentalProject.parse(LocalFile.boundedData(url,limit:ExperimentalProject.byteLimit,label:"Project"),at:url)
        let lyrics=try LyricsParser.parse(LocalFile.boundedData(project.lyrics,limit:LRCParser.byteLimit,label:"Lyrics"),format:project.lyricsFormat)
            .applyingProjectOffset(project.offsetMilliseconds)
        let artwork=try project.artwork.map(LocalArtwork.decode)
        let audio=try await LocalAudio.decode(project.audio)
        let scene=try LocalScene(lyrics:lyrics,audio:audio,project:project,artwork:artwork?.image,highlighting:project.highlighting)
        return .init(project:project,scene:scene,artworkInfo:artwork?.info)
    }
}
