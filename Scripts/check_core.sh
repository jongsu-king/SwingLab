#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
CHECK_DIR=$(mktemp -d /tmp/swinglab-checks.XXXXXX)
trap 'rm -rf "$CHECK_DIR"' EXIT
swiftc -swift-version 6 -enable-testing -emit-library -emit-module -module-name SwingLabCore Sources/SwingLabCore/*.swift -emit-module-path "$CHECK_DIR/SwingLabCore.swiftmodule" -o "$CHECK_DIR/libSwingLabCore.dylib"
swiftc -swift-version 6 -parse-as-library -I "$CHECK_DIR" -L "$CHECK_DIR" -lSwingLabCore -Xlinker -rpath -Xlinker "$CHECK_DIR" Tests/SwingLabCoreTests/*.swift Scripts/PortableTestHarness.swift -o "$CHECK_DIR/CoreChecks"
"$CHECK_DIR/CoreChecks"
