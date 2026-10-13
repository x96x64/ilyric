# Formula for the x96x64/homebrew-tap repository (docs/distribution.md). The URL and SHA-256 are set for each
# release; version 0.1.0 predates the rename, so the tap keeps its `ilyric` formula until the first `ilyrics` release.
class Ilyrics < Formula
  desc "Lyrics videos of the iPhone Music Lyrics screen, with on-device synchronization"
  homepage "https://github.com/x96x64/ilyrics"
  url "https://github.com/x96x64/ilyrics/archive/refs/tags/v1.1.0.tar.gz"
  sha256 "ed0e55e3774719bd3e476015c464dcdc21c1401d3ee1780de6e75fda83b91416"
  license "Apache-2.0"
  head "https://github.com/x96x64/ilyrics.git", branch: "main"

  depends_on arch: :arm64
  depends_on macos: :sonoma

  def install
    system "swift", "build", "--disable-sandbox", "-c", "release", "--product", "ilyrics"
    bin.install ".build/release/ilyrics"
    (share/"ilyrics").install "share/ilyrics/templates"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/ilyrics --version")
    assert_match "share/ilyrics/templates", shell_output("#{bin}/ilyrics models status")
  end
end
