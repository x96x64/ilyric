import Foundation
import CryptoKit
import AlignmentCore

/// Pinned downloads for first launch: a file is kept only when its SHA-256 matches, and a verified copy is reused.
public enum ModelStore {
    /// The user's cache directory for iLyric models.
    public static var defaultDirectory: URL {
        FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("iLyric/Models",isDirectory:true)
    }

    /// Returns the local file for `url`, downloading it when absent or corrupted.
    public static func fetch(_ url: URL, sha256: String, into directory: URL, name: String) async throws -> URL {
        let fm=FileManager.default
        try fm.createDirectory(at:directory,withIntermediateDirectories:true)
        let target=directory.appendingPathComponent(name)
        if fm.fileExists(atPath:target.path) {
            if try digest(target)==sha256 { return target }
            try fm.removeItem(at:target)
        }
        let (temporary,response)=try await URLSession.shared.download(from:url)
        defer { try? fm.removeItem(at:temporary) }
        if let http=response as? HTTPURLResponse,!(200..<300).contains(http.statusCode) {
            throw AlignmentError.invalid("Download of \(name) failed with HTTP \(http.statusCode)")
        }
        guard try digest(temporary)==sha256 else { throw AlignmentError.invalid("Downloaded \(name) does not match its pinned SHA-256") }
        try fm.moveItem(at:temporary,to:target)
        return target
    }

    static func digest(_ url: URL) throws -> String {
        let handle=try FileHandle(forReadingFrom:url);defer { try? handle.close() }
        var hasher=SHA256()
        while let chunk=try handle.read(upToCount:1<<20),!chunk.isEmpty { hasher.update(data:chunk) }
        return hasher.finalize().map { String(format:"%02x",$0) }.joined()
    }
}
