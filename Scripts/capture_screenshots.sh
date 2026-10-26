#!/bin/bash
# Capture real XCTest screenshots. Requires an installed iOS Simulator runtime.
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$TASK_ROOT"
TASK_DESTINATION="${1:-}"
if [[ -z "$TASK_DESTINATION" ]]; then
  TASK_DEVICE_ID="$(xcrun simctl list devices available --json | python3 -c '
import json,sys
data=json.load(sys.stdin)
for devices in data.get("devices",{}).values():
    for device in devices:
        if device.get("isAvailable") and device.get("name", "").startswith("iPhone"):
            print(device["udid"])
            sys.exit(0)
print("No available iPhone simulator. Install an iOS runtime, then rerun.",file=sys.stderr)
sys.exit(2)
')"
  TASK_DESTINATION="platform=iOS Simulator,id=$TASK_DEVICE_ID"
fi
TASK_RUN="$(date +%Y%m%d-%H%M%S)-$$"
TASK_RESULT="$TASK_ROOT/DerivedData/Screenshots-$TASK_RUN.xcresult"
TASK_ATTACHMENTS="$TASK_ROOT/DerivedData/ScreenshotAttachments-$TASK_RUN"
TASK_OUTPUT="$TASK_ROOT/Docs/Screenshots/round-3"
mkdir -p "$TASK_ROOT/Docs/Logs" "$TASK_OUTPUT"
xcodebuild -project SwingLab.xcodeproj -scheme SwingLab \
  -destination "$TASK_DESTINATION" -derivedDataPath ./DerivedData \
  -resultBundlePath "$TASK_RESULT" CODE_SIGNING_ALLOWED=NO \
  -parallel-testing-enabled NO -only-testing:SwingLabUITests/ScreenshotTests test \
  | tee "$TASK_ROOT/Docs/Logs/screenshots-$TASK_RUN.log"
xcrun xcresulttool export attachments --path "$TASK_RESULT" --output-path "$TASK_ATTACHMENTS"
python3 - "$TASK_ATTACHMENTS" "$TASK_OUTPUT" "$TASK_RESULT" <<'PY'
import json,re,shutil,sys
from pathlib import Path
source,output,result=map(Path,sys.argv[1:])
manifest=json.loads((source/'manifest.json').read_text())
# Xcode 27.1 `xcresulttool export attachments --schema` describes an array of
# test entries whose attachment fields include the two names used below.
pattern=re.compile(r'(round3-(?:en|ko|de)-(?:light|dark)-(?:home|swing|swing-detail-empty|flight|course|performance|settings|bag))(?:\.[A-Za-z0-9]+)?$')
captured={}
for test in manifest:
    for attachment in test.get('attachments',[]):
        match=pattern.fullmatch(attachment.get('suggestedHumanReadableName',''))
        if not match:
            continue
        original=source/attachment['exportedFileName']
        # Never invent a screenshot entry for a missing or failed attachment.
        if not original.is_file():
            raise SystemExit(f'Missing exported attachment: {original}')
        destination=output/(match.group(1)+'.png')
        if original.read_bytes()[:8] != b'\x89PNG\r\n\x1a\n':
            raise SystemExit(f'Expected PNG screenshot: {original}')
        shutil.copyfile(original,destination)
        captured[match.group(1)]={'file':destination.name,'test':test['testIdentifier'],
            'device':attachment.get('deviceName'),'deviceID':attachment.get('deviceId'),
            'timestamp':attachment.get('timestamp')}
actual={'resultBundle':str(result),'screenshots':[captured[key] for key in sorted(captured)]}
(output/'manifest.json').write_text(json.dumps(actual,ensure_ascii=False,indent=2)+'\n')
expected={f'round3-{language}-{appearance}-{screen}' for language in ['en','ko','de']
    for appearance in ['light','dark'] for screen in ['home','swing','swing-detail-empty','flight','course','performance','settings','bag']}
missing=expected-captured.keys()
print(f'Exported {len(captured)} actual screenshots to {output}.')
if missing:
    raise SystemExit('Missing screenshots: '+', '.join(sorted(missing)))
PY
