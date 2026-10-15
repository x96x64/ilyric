import Foundation
import Testing
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import LyricsInputCore
import LyricsInputMac

struct InputAuditTests {
    @Test func malformedLyricsFailWithoutTrapping() throws {
        for parser in [LRCParser.parse, EnhancedLRCParser.parse, TTMLParser.parse] {
            for data in [Data(), Data([0xff, 0xfe]), Data(repeating: 65, count: 65_537), Data([0])] {
                #expect(throws: (any Error).self) { _ = try parser(data) }
            }
        }
        for time in [
            "", "NaNs", "infs", "999999999.999999h", "999999999:59:59.999999", "1e309s", "1200.000001s", "-0.1s", ".s",
        ] {
            #expect(throws: (any Error).self) { _ = try TTMLParser.time(time) }
        }
        for text in [
            "[9999999999999999999999:00]x", "[offset:9223372036854775807]\n[00:00]x", "[00:60]x", "[00:00]x\n[00:00]y",
            "[00:00]x\u{0000}",
        ] {
            #expect(throws: (any Error).self) { _ = try LRCParser.parse(Data(text.utf8)) }
        }
        let prefix = "<tt xmlns=\"http://www.w3.org/ns/ttml\"><body><div>"
        for body in [
            "<p begin=\"1s\" end=\"0s\">x</p>", "<p begin=\"0s\" end=\"1s\">&unknown;</p>",
            String(repeating: "<div>", count: 100),
        ] {
            #expect(throws: (any Error).self) {
                _ = try TTMLParser.parse(Data((prefix + body + "</div></body></tt>").utf8))
            }
        }
        #expect(throws: (any Error).self) {
            _ = try TTMLParser.parse(Data("<!DOCTYPE tt [<!ENTITY x SYSTEM 'file:///nonexistent'>]><tt/>".utf8))
        }
    }

    @Test func deterministicMutationsStayWithinParserLimits() throws {
        let cases: [(String, (Data) throws -> LocalLyrics)] = [
            ("[00:00.100]Paper boats\n[00:01.000]Drift away", LRCParser.parse),
            ("[00:00.100]<00:00.100>Paper <00:00.500>boats<00:00.900>", EnhancedLRCParser.parse),
            (
                "<tt xmlns=\"http://www.w3.org/ns/ttml\"><body><div><p begin=\"0s\" end=\"1s\">Paper boats</p></div></body></tt>",
                TTMLParser.parse
            ),
        ]
        for (source, parse) in cases {
            let original = Array(source.utf8)
            for i in original.indices {
                for byte: UInt8 in [0, 34, 60, 62, 255] {
                    var changed = original
                    changed[i] = byte
                    if let result = try? parse(Data(changed)) {
                        #expect(!result.entries.isEmpty && result.entries.count <= LRCParser.eventLimit)
                        try result.validateSegments()
                    }
                }
            }
        }
    }

    @Test func artworkRejectsCorruptionAndPreservesTransparency() throws {
        for data in [Data(), Data([0x89, 0x50, 0x4e, 0x47]), Data("not an image".utf8)] {
            #expect(throws: (any Error).self) { _ = try LocalArtwork.decode(data: data) }
        }
        for width in [2, 8193] {
            let context = try #require(
                CGContext(
                    data: nil, width: width, height: 1, bitsPerComponent: 8, bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.clear(CGRect(x: 0, y: 0, width: width, height: 1))
            let image = try #require(context.makeImage())
            let data = NSMutableData()
            let destination = try #require(
                CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
            CGImageDestinationAddImage(destination, image, nil)
            try #require(CGImageDestinationFinalize(destination))
            if width == 8193 {
                #expect(throws: (any Error).self) { _ = try LocalArtwork.decode(data: data as Data) }
            } else {
                let decoded = try LocalArtwork.decode(data: data as Data)
                #expect(decoded.info.width == width)
                let bytes = try #require(decoded.image.dataProvider?.data) as Data
                #expect(bytes.allSatisfy { $0 == 0 })
            }
        }
    }
}
