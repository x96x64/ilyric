#!/bin/sh
set -eu
# Swift 6.4 Command Line Tools omit Testing discovery paths in Swift Build.
# Derive paths from the selected toolchain; do not embed a developer's home directory.
developer_dir=$(xcode-select -p)
plugin="$developer_dir/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
frameworks="$developer_dir/Library/Developer/Frameworks"
if [ -f "$plugin" ] && [ -d "$frameworks/Testing.framework" ]; then
    exec swift test --disable-xctest -Xswiftc -load-plugin-library -Xswiftc "$plugin" \
        -Xlinker -rpath -Xlinker "$frameworks" \
        -Xlinker -rpath -Xlinker "$developer_dir/Library/Developer/usr/lib" "$@"
fi
exec swift test --disable-xctest "$@"
