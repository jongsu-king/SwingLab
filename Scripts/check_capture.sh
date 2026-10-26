#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
CAPTURE_CHECK_DIR=$(mktemp -d /tmp/swinglab-capture.XXXXXX)
trap 'rm -rf "$CAPTURE_CHECK_DIR"' EXIT
swiftc -swift-version 6 -target arm64-apple-macosx14.0 -emit-library -emit-module -module-name SwingLabCore Sources/SwingLabCore/*.swift -emit-module-path "$CAPTURE_CHECK_DIR/SwingLabCore.swiftmodule" -o "$CAPTURE_CHECK_DIR/libSwingLabCore.dylib"
cp Scripts/CaptureModelChecks.swift "$CAPTURE_CHECK_DIR/main.swift"
swiftc -swift-version 6 -target arm64-apple-macosx14.0 -I "$CAPTURE_CHECK_DIR" -L "$CAPTURE_CHECK_DIR" -lSwingLabCore -Xlinker -rpath -Xlinker "$CAPTURE_CHECK_DIR" "$CAPTURE_CHECK_DIR/main.swift" -o "$CAPTURE_CHECK_DIR/CaptureChecks"
"$CAPTURE_CHECK_DIR/CaptureChecks"
swiftc -swift-version 6 -target arm64-apple-macosx14.0 -I "$CAPTURE_CHECK_DIR" -typecheck SwingLab/Services/PoseEstimationService.swift SwingLab/Services/AudioImpactReader.swift SwingLab/Services/VideoLibrary.swift SwingLab/Services/VideoPlaybackController.swift
echo 'PASS shared macOS AVFoundation/Vision/Transferable service typecheck (not an iOS build)'
swiftc -swift-version 6 -target arm64-apple-macosx14.0 -I "$CAPTURE_CHECK_DIR" -L "$CAPTURE_CHECK_DIR" -lSwingLabCore -Xlinker -rpath -Xlinker "$CAPTURE_CHECK_DIR" -parse-as-library SwingLab/Services/PoseEstimationService.swift SwingLab/Services/AudioImpactReader.swift SwingLab/Services/VideoLibrary.swift Scripts/VideoAnalysisChecks.swift -o "$CAPTURE_CHECK_DIR/VideoAnalysisChecks"
"$CAPTURE_CHECK_DIR/VideoAnalysisChecks"
