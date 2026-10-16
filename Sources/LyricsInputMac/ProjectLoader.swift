import Foundation
import ImageIO
import CoreGraphics
import LyricsInputCore

public enum LocalFile {
    public static func boundedData(_ url: URL, limit: Int, label: String) throws -> Data {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
            size.isRegularFile == true,
            let count = size.fileSize, count <= limit, FileManager.default.isReadableFile(atPath: url.path)
        else {
            throw InputError.invalid("\(label) is missing, inaccessible, not a regular file, or exceeds its byte limit")
        }
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let data = try handle.read(upToCount: limit + 1) ?? Data()
            guard data.count <= limit else { throw InputError.invalid("\(label) exceeds its byte limit") }
            return data
        } catch let error as InputError { throw error } catch { throw InputError.invalid("\(label) could not be read") }
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
        try decode(data: LocalFile.boundedData(url, limit: 16 * 1024 * 1024, label: "Artwork"))
    }
    /// ImageIO may return pixels from truncated PNG streams without reporting an incomplete source.
    /// Check chunk extents and the terminal chunk before accepting those pixels.
    private static func requireCompletePNG(_ data: Data) throws {
        guard data.starts(with: [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]) else { return }
        let complete = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> Bool in
            var offset = 8
            while bytes.count - offset >= 12 {
                let count = (0..<4).reduce(0) { ($0 << 8) | Int(bytes[offset + $1]) }
                guard count <= bytes.count - offset - 12 else { return false }
                if bytes[offset + 4] == 0x49, bytes[offset + 5] == 0x45,
                    bytes[offset + 6] == 0x4e, bytes[offset + 7] == 0x44
                {
                    return count == 0
                }
                offset += count + 12
            }
            return false
        }
        guard complete else { throw InputError.invalid("Artwork PNG is incomplete or has an invalid chunk length") }
    }
    /// Decodes artwork bytes, such as the cover embedded in an audio file.
    public static func decode(data: Data) throws -> LocalArtwork {
        guard data.count <= 16 * 1024 * 1024 else { throw InputError.invalid("Artwork exceeds its byte limit") }
        try requireCompletePNG(data)
        guard
            let source = CGImageSourceCreateWithData(
                data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
            CGImageSourceGetCount(source) == 1,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int,
            (1...8192).contains(width), (1...8192).contains(height), width * height <= 67_108_864
        else {
            throw InputError.invalid(
                "Artwork must be one decodable image within 8192 pixels per side and 64 megapixels")
        }
        // ImageIO applies EXIF orientation and bounds decode to 1024 pixels. Embedded
        // color space is honored by drawing into the explicit sRGB destination.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 1024,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
            let c = CGContext(
                data: nil, width: decoded.width, height: decoded.height, bitsPerComponent: 8,
                bytesPerRow: decoded.width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            throw InputError.invalid("Artwork decoding failed")
        }
        c.draw(decoded, in: CGRect(x: 0, y: 0, width: decoded.width, height: decoded.height))
        guard let image = c.makeImage() else { throw InputError.invalid("Artwork color conversion failed") }
        return .init(
            image: image,
            info: .init(
                width: width, height: height, reportedColorProfile: properties[kCGImagePropertyProfileName] != nil))
    }
}
/// Full preparation occurs before export, including hidden assets and paragraph bounds.
public struct PreparedProject {
    public let project: ProjectSettings
    public let scene: LocalScene
    public let artworkInfo: ArtworkInfo?
    public static func load(_ url: URL, presentation: LocalPresentation = .init()) async throws -> PreparedProject {
        let project = try ProjectSettings.parse(
            LocalFile.boundedData(url, limit: ProjectSettings.byteLimit, label: "Project"), at: url)
        let lyrics = try LyricsParser.parse(
            LocalFile.boundedData(project.lyrics, limit: LRCParser.byteLimit, label: "Lyrics"),
            format: project.lyricsFormat
        )
        .applyingProjectOffset(project.offsetMilliseconds)
        let artwork = try project.artwork.map(LocalArtwork.decode)
        let audio = try await LocalAudio.decode(project.audio)
        let scene = try LocalScene(
            lyrics: lyrics, audio: audio, project: project, artwork: artwork?.image, highlighting: project.highlighting,
            presentation: presentation)
        return .init(project: project, scene: scene, artworkInfo: artwork?.info)
    }
}
