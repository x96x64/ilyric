import Foundation
import Testing

extension InputTests {
    /// The command names the file, the line, and the character before any model work. Synthetic text.
    @Test func lyricProblemsAreReportedWithFileLineAndCharacter() throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let executable=root.appendingPathComponent(".build/debug/ilyrics")
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:dir) }
        let audio=dir.appendingPathComponent("fixture.wav");try Data().write(to:audio)
        let cases:[(String,String)]=[
            ("","input.txt is empty"),
            ("\n  \n","input.txt is empty"),
            ("[Verse 1]\nWritten by: Somebody\n...\n","input.txt contains no lines to sing"),
            ("[Verse 1]\nFirst line\n\nWe walked 3.5 miles\n","line 4 of input.txt contains \"3\" (U+0033)"),
            ("First line\nSecond 日\n","line 2 of input.txt contains \"日\" (U+65E5)"),
            ("Pay me $5\n","line 1 of input.txt contains \"$\" (U+0024)")]
        for (text,expected) in cases {
            let input=dir.appendingPathComponent("input.txt");try text.write(to:input,atomically:true,encoding:.utf8)
            let p=Process(),err=Pipe()
            p.executableURL=executable;p.arguments=["align",audio.path,input.path,"-o",dir.appendingPathComponent("out.ttml").path,"--force"]
            var env=ProcessInfo.processInfo.environment;env["ILYRICS_TEMPLATES"]=dir.appendingPathComponent("missing").path
            p.environment=env;p.standardError=err;p.standardOutput=Pipe()
            try p.run();p.waitUntilExit()
            let stderr=String(decoding:err.fileHandleForReading.readDataToEndOfFile(),as:UTF8.self)
            #expect(p.terminationStatus==1)
            #expect(stderr.contains("Error: "+expected),"\(stderr)")
            #expect(!stderr.contains("Japanese excerpt") && !stderr.contains("invalid("))
        }
    }
}
