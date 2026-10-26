#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
python3 Scripts/build_localizations.py
python3 Scripts/generate_project.py
swift build
if [[ "$(xcode-select -p)" == *Xcode*.app/Contents/Developer ]]; then
    swift test
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
