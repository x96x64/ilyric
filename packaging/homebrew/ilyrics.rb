# Formula for the x96x64/homebrew-tap repository (docs/distribution.md). The URL and SHA-256 are set for each
# release; the tap's formula_renames.json migrates installations of the former `ilyric` formula.
class Ilyrics < Formula
  desc "Lyrics videos of the iPhone Music Lyrics screen, with on-device synchronization"
  homepage "https://github.com/x96x64/ilyrics"
  url "https://github.com/x96x64/ilyrics/archive/refs/tags/v1.3.0.tar.gz"
  sha256 "95a1f285a50b8b8ed0866918b50d1a62f4d02d8a25ab5d51abb3a220e75d7ba9"
  license "Apache-2.0"
  head "https://github.com/x96x64/ilyrics.git", branch: "main"

  depends_on arch: :arm64
  depends_on macos: :sonoma

  def install
    # Package.swift needs Swift 6 tools, from Xcode 16 or the Command Line Tools 16 or later.
    swift = Utils.safe_popen_read("swift", "--version")[/Swift version (\d+)/, 1].to_i
    if swift < 6
      odie "iLyrics needs Swift 6 or later to build; install Xcode 16 or the Command Line Tools 16 or later"
    end
    system "swift", "build", "--disable-sandbox", "-c", "release", "--product", "ilyrics"
    bin.install ".build/release/ilyrics"
    (share/"ilyrics").install "share/ilyrics/templates"
  end

  def caveats
    <<~EOS
      Alignment models (about 460 MB) are downloaded on first use into
        ~/Library/Application Support/iLyrics/Models
      Run `ilyrics models remove` before uninstalling to delete them.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/ilyrics --version") unless version.head?
    assert_match "share/ilyrics/templates", shell_output("#{bin}/ilyrics models status")
  end
end
