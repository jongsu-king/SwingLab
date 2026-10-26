# Round 3 screenshots

**48 actual screenshots**, captured on iPhone Duo with iOS 27.1 (24A94425), in English, Korean, and German, each in light and dark appearance. The [capture manifest](manifest.json) records the test, device, timestamp, result bundle, and SHA-256 of every PNG. Only exported files appear in it.

The full six-variant screenshot run passed after correcting prominent-button contrast. A targeted six-image refresh then passed after fixing German camera-angle truncation and the missing “Measured” translations. The [design audit](../../DesignAudit.md) records observed corrections and remaining WP7 work.

| Screen | English light | English dark | Korean light | Korean dark | German light | German dark |
|---|---|---|---|---|---|---|
| Home | [PNG](round3-en-light-home.png) | [PNG](round3-en-dark-home.png) | [PNG](round3-ko-light-home.png) | [PNG](round3-ko-dark-home.png) | [PNG](round3-de-light-home.png) | [PNG](round3-de-dark-home.png) |
| Swing | [PNG](round3-en-light-swing.png) | [PNG](round3-en-dark-swing.png) | [PNG](round3-ko-light-swing.png) | [PNG](round3-ko-dark-swing.png) | [PNG](round3-de-light-swing.png) | [PNG](round3-de-dark-swing.png) |
| Swing detail — empty | [PNG](round3-en-light-swing-detail-empty.png) | [PNG](round3-en-dark-swing-detail-empty.png) | [PNG](round3-ko-light-swing-detail-empty.png) | [PNG](round3-ko-dark-swing-detail-empty.png) | [PNG](round3-de-light-swing-detail-empty.png) | [PNG](round3-de-dark-swing-detail-empty.png) |
| Hypothetical flight — simulated driver example | [PNG](round3-en-light-flight.png) | [PNG](round3-en-dark-flight.png) | [PNG](round3-ko-light-flight.png) | [PNG](round3-ko-dark-flight.png) | [PNG](round3-de-light-flight.png) | [PNG](round3-de-dark-flight.png) |
| Course | [PNG](round3-en-light-course.png) | [PNG](round3-en-dark-course.png) | [PNG](round3-ko-light-course.png) | [PNG](round3-ko-dark-course.png) | [PNG](round3-de-light-course.png) | [PNG](round3-de-dark-course.png) |
| Performance | [PNG](round3-en-light-performance.png) | [PNG](round3-en-dark-performance.png) | [PNG](round3-ko-light-performance.png) | [PNG](round3-ko-dark-performance.png) | [PNG](round3-de-light-performance.png) | [PNG](round3-de-dark-performance.png) |
| Settings | [PNG](round3-en-light-settings.png) | [PNG](round3-en-dark-settings.png) | [PNG](round3-ko-light-settings.png) | [PNG](round3-ko-dark-settings.png) | [PNG](round3-de-light-settings.png) | [PNG](round3-de-dark-settings.png) |
| My Bag | [PNG](round3-en-light-bag.png) | [PNG](round3-en-dark-bag.png) | [PNG](round3-ko-light-bag.png) | [PNG](round3-ko-dark-bag.png) | [PNG](round3-de-light-bag.png) | [PNG](round3-de-dark-bag.png) |

## Reproduce

```sh
Scripts/capture_screenshots.sh
# Or choose an installed, compatible iPhone explicitly:
Scripts/capture_screenshots.sh 'platform=iOS Simulator,name=iPhone Duo'
```

The script runs the real navigation screenshot tests and uses Xcode 27.1's `xcresulttool export attachments`. It fails if any of the 48 required images is missing. It prefers an available conventional iPhone when possible. This installed runtime supports only iPhone Duo/arm64; an attempted iPhone 18 Pro creation was rejected as incompatible.

All screenshot launches use a DEBUG-only in-memory library and isolated preferences. Seven screens show an empty library. Swing detail uses a separate launch with one missing-video recording and no analysis; the real missing-file alert is dismissed before capture. The tour-average flight example is filled only by tapping the real example button. No fixture is stored in the production library.

Evidence:

- [Full matrix log: six UI tests passed](../../Logs/screenshots-20261026-211342-18947.log).
- [Final native log: 17 app tests plus navigation and detail refresh passed](../../Logs/round3-final-native.log).
- [Detail attachment export](../../Logs/round3-detail-export.log).

After testing, the app was also explicitly installed with `xcrun simctl install` and launched with `xcrun simctl launch` without test arguments. No simulator data reset or app uninstall was performed.
