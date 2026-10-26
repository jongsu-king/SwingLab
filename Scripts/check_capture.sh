#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
CAPTURE_CHECK_DIR=$(mktemp -d /tmp/swinglab-capture.XXXXXX)
trap 'rm -rf "$CAPTURE_CHECK_DIR"' EXIT
python3 - "$CAPTURE_CHECK_DIR" <<'PY'
import pathlib, sys
source = pathlib.Path('SwingLab/Core/Models/SwingRecording.swift').read_text()
# Compile the actual Codable value types without the unavailable SwiftData macro plugin.
models = 'import Foundation\n\nstruct PoseJoint' + source.split('struct PoseJoint', 1)[1]
pathlib.Path(sys.argv[1], 'PoseModels.swift').write_text(models)
pathlib.Path(sys.argv[1], 'main.swift').write_text(pathlib.Path('Scripts/CaptureModelChecks.swift').read_text())
PY
swiftc -swift-version 6 "$CAPTURE_CHECK_DIR/PoseModels.swift" "$CAPTURE_CHECK_DIR/main.swift" -o "$CAPTURE_CHECK_DIR/CaptureChecks"
"$CAPTURE_CHECK_DIR/CaptureChecks"
swiftc -swift-version 6 -target arm64-apple-macosx14.0 -typecheck "$CAPTURE_CHECK_DIR/PoseModels.swift" SwingLab/Services/PoseEstimationService.swift SwingLab/Services/VideoLibrary.swift SwingLab/Services/VideoPlaybackController.swift
echo 'PASS shared macOS AVFoundation/Vision/Transferable service typecheck (not an iOS build)'
swiftc -swift-version 6 -target arm64-apple-macosx14.0 -parse-as-library "$CAPTURE_CHECK_DIR/PoseModels.swift" SwingLab/Services/PoseEstimationService.swift SwingLab/Services/VideoLibrary.swift Scripts/VideoAnalysisChecks.swift -o "$CAPTURE_CHECK_DIR/VideoAnalysisChecks"
"$CAPTURE_CHECK_DIR/VideoAnalysisChecks"
