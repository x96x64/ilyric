#!/bin/sh
# Stage a built ilyrics and produce the release archive, npm package, and wheel (docs/distribution.md).
# Usage: packaging/package.sh VERSION BINARY OUTDIR
set -eu
version=$1 binary=$2 out=$3
root=$(cd "$(dirname "$0")/.." && pwd)
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/bin" "$stage/share/ilyrics" "$out"
out=$(cd "$out" && pwd)
install -m 755 "$binary" "$stage/bin/ilyrics"
# Remove local symbols (about 1 MB) and re-sign ad hoc, since Apple silicon refuses to run an unsigned binary.
strip -x "$stage/bin/ilyrics"
codesign --force --sign - "$stage/bin/ilyrics"
cp -R "$root/share/ilyrics/templates" "$stage/share/ilyrics/"
cp "$root/LICENSE" "$stage/"
# The package README uses absolute links, unlike the repository README.
cp "$root/packaging/README.md" "$stage/README.md"
# Release archive.
tar -C "$stage" -czf "$out/ilyrics-$version-macos-arm64.tar.gz" bin share LICENSE README.md
# npm package: the same files; npm marks the bin target executable.
sed "s/__VERSION__/$version/" "$root/packaging/npm/package.json" > "$stage/package.json"
(cd "$stage" && npm pack --silent --pack-destination "$out" >/dev/null)
# Platform wheel.
python3 "$root/packaging/build_wheel.py" "$stage" "$version" "$out" >/dev/null
(cd "$out" && shasum -a 256 ilyrics-* > SHA256SUMS)
ls "$out"
