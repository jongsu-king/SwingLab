# Round 3 screenshots

No screenshots have been exported yet. The iOS 27.1 runtime (24A94425) became available during Round 3, with the iPhone Duo simulator. Native tests and captures are in progress; this file will be updated only after actual export.

Once an iOS runtime and iPhone simulator are available, run:

```sh
Scripts/capture_screenshots.sh
# Or select a destination explicitly:
Scripts/capture_screenshots.sh 'platform=iOS Simulator,name=iPhone 17'
```

The test visits actual app screens and attaches PNGs for Home, Swing, swing detail without analysis/video, hypothetical flight after filling the driver example and simulating, Course, Performance, Settings, and My Bag. It runs English, Korean, and German in light and dark appearances: 48 required images. The script exports attachments with Xcode 27.1's `xcresulttool export attachments` and writes `manifest.json` containing **only files actually exported**, including source test/device/timestamp evidence. A missing capture fails the script.

All launches use a DEBUG-only in-memory library and isolated preferences. Seven screens show an empty library. Swing detail uses a separate launch with one missing-video recording and no analysis; its missing-file alert is dismissed before capture. The tour-average launch example is filled only by tapping the real example button. No screenshot fixture is stored in the production library. No screenshot-based design validation is claimed until the captures exist and are inspected.
