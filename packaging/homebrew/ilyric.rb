# Formula for the x96x64/homebrew-tap repository (docs/distribution.md).
class Ilyric < Formula
  desc "Lyrics videos of the iPhone Music Lyrics screen, with on-device synchronization"
  homepage "https://github.com/x96x64/ilyric"
  url "https://github.com/x96x64/ilyric/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "a7cf0357407268264373f99ba21b47a62232c5738c50fca6338a9290f094b262"
  license "Apache-2.0"
  head "https://github.com/x96x64/ilyric.git", branch: "main"

  depends_on arch: :arm64
  depends_on macos: :sonoma

  def install
    system "swift", "build", "--disable-sandbox", "-c", "release", "--product", "ilyric"
    bin.install ".build/release/ilyric"
    (share/"ilyric").install "share/ilyric/templates"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/ilyric --version")
    assert_match "share/ilyric/templates", shell_output("#{bin}/ilyric models status")
  end
end
