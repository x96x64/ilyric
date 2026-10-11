#!/bin/sh
# Stage a built ilyric and produce the release archive, npm package, and wheel (docs/distribution.md).
# Usage: packaging/package.sh VERSION BINARY OUTDIR
set -eu
version=$1 binary=$2 out=$3
root=$(cd "$(dirname "$0")/.." && pwd)
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/bin" "$stage/share/ilyric" "$out"
install -m 755 "$binary" "$stage/bin/ilyric"
cp -R "$root/share/ilyric/templates" "$stage/share/ilyric/"
cp "$root/LICENSE" "$root/README.md" "$stage/"
# Release archive.
tar -C "$stage" -czf "$out/ilyric-$version-macos-arm64.tar.gz" bin share LICENSE README.md
# npm package: the same files; npm marks the bin target executable.
sed "s/__VERSION__/$version/" "$root/packaging/npm/package.json" > "$stage/package.json"
(cd "$stage" && npm pack --silent --pack-destination "$out" >/dev/null)
# Platform wheel.
python3 "$root/packaging/build_wheel.py" "$stage" "$version" "$out" >/dev/null
(cd "$out" && shasum -a 256 ilyric-* > SHA256SUMS)
ls "$out"
