#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
COURSE_CHECK_DIR=$(mktemp -d /tmp/swinglab-course.XXXXXX)
trap 'rm -rf "$COURSE_CHECK_DIR"' EXIT
swiftc -swift-version 6 -target arm64-apple-macosx14.0 -emit-library -emit-module -module-name SwingLabCore Sources/SwingLabCore/*.swift -emit-module-path "$COURSE_CHECK_DIR/SwingLabCore.swiftmodule" -o "$COURSE_CHECK_DIR/libSwingLabCore.dylib"
python3 - "$COURSE_CHECK_DIR" <<'PY'
import pathlib, sys
source = pathlib.Path('SwingLab/Core/Models/CourseModels.swift').read_text()
# Test the actual value definitions without the unavailable SwiftData macro plugin.
references = 'struct CourseReferencePoint' + source.split('struct CourseReferencePoint', 1)[1].split('@Model', 1)[0]
score = 'struct ScorecardEntry' + source.split('struct ScorecardEntry', 1)[1]
pathlib.Path(sys.argv[1], 'CourseValues.swift').write_text('import Foundation\nimport SwingLabCore\n' + references + '\n' + score)
pathlib.Path(sys.argv[1], 'main.swift').write_text(pathlib.Path('Scripts/CourseModelChecks.swift').read_text())
PY
swiftc -swift-version 6 -target arm64-apple-macosx14.0 -I "$COURSE_CHECK_DIR" -L "$COURSE_CHECK_DIR" -lSwingLabCore -Xlinker -rpath -Xlinker "$COURSE_CHECK_DIR" "$COURSE_CHECK_DIR/CourseValues.swift" SwingLab/Services/LocationService.swift "$COURSE_CHECK_DIR/main.swift" -o "$COURSE_CHECK_DIR/CourseChecks"
"$COURSE_CHECK_DIR/CourseChecks"
swiftc -swift-version 6 -target arm64-apple-macosx14.0 -I "$COURSE_CHECK_DIR" -typecheck SwingLab/Services/LocationService.swift SwingLab/Services/GolfCourseService.swift
echo 'PASS shared macOS CoreLocation/MapKit services typecheck (not an iOS build)'
