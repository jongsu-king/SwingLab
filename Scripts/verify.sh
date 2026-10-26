#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
# Keep compiler caches inside the checkout in restricted workspaces.
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
mkdir -p "$CLANG_MODULE_CACHE_PATH" .build/SwiftPMCache
python3 Scripts/build_localizations.py
python3 Scripts/generate_project.py
# Legacy labels are accepted only by enum decoders, never compared by domain/UI logic.
if rg -n '(provenance|Provenance)\s*(==|!=)\s*"|provenance:\s*"' Sources SwingLab --glob '*.swift'; then
    echo 'FAIL string-literal provenance comparison or initializer'
    exit 1
fi
echo 'PASS no string-literal provenance comparisons or initializers'
# SwiftPM's nested sandbox cannot initialize inside the workspace sandbox.
# This package has no external dependencies or build plugins; the outer sandbox stays active.
swift build --disable-sandbox --cache-path .build/SwiftPMCache --manifest-cache local
if [[ "$(xcode-select -p)" == *Xcode*.app/Contents/Developer ]]; then
    swift test
    # Supplemental real SwiftData disk checks; iOS simulator XCTest remains a separate gate.
    Scripts/check_migrations.sh
else
    Scripts/check_core.sh
fi
Scripts/check_capture.sh
Scripts/check_course.sh
while IFS= read -r source; do
    swiftc -frontend -parse "$source"
done < <(rg --files SwingLab SwingLabTests SwingLabUITests -g '*.swift')
plutil -lint SwingLab.xcodeproj/project.pbxproj SwingLab/Resources/Info.plist SwingLab/Resources/PrivacyInfo.xcprivacy
python3 - <<'PY'
import json, pathlib, xml.etree.ElementTree as ET
for p in pathlib.Path('SwingLab/Resources').rglob('*.json'):
    json.load(open(p))
for p in pathlib.Path('SwingLab/Resources').glob('*.xcstrings'):
    content=json.load(open(p))
    assert content['sourceLanguage']=='en'
ET.parse('SwingLab.xcodeproj/xcshareddata/xcschemes/SwingLab.xcscheme')
gaps=json.load(open('Docs/LocalizationGaps.json'))
if gaps:
    print(f'Localization incomplete: {len(gaps)} keys. See Docs/LocalizationGaps.json.')
    raise SystemExit(1)
print('Catalogs and project syntax validated. Parsing does not validate iOS compilation.')
PY
