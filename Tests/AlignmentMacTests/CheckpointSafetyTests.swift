import Foundation
import Testing
@testable import AlignmentMac

extension CheckpointTests {
    @Test func malformedZipOffsetsThrow() throws {
        var bytes = Data(repeating: 0, count: 22)
        bytes.replaceSubrange(0..<4, with: [0x50, 0x4b, 0x05, 0x06])
        bytes[10] = 1
        bytes[16] = 255
        #expect(throws: (any Error).self) { _ = try StoredZip(bytes) }
    }
}
