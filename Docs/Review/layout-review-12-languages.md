# Layout review in 12 languages (reviewer, 27 Oct 2026)

Acceptance A2 and A15 ask for every primary screen to be reviewed in 12 languages, in light and dark mode.

English, Korean, and German were already captured in light and dark (`Docs/Screenshots/round-4/`). This pass adds the other nine languages: Japanese, Chinese (Simplified), Chinese (Traditional), Spanish, Portuguese (Brazil), French, Italian, Thai, and Vietnamese.

**How it was captured**
- Opt-in UI test `ScreenshotTests.testRemainingLanguagesLight`, iPhone 17 Pro, iOS 26.4, light mode. Run it with:
  `xcodebuild … TEST_RUNNER_SWINGLAB_ALL_LANGUAGES=1 -only-testing:SwingLabUITests/ScreenshotTests/testRemainingLanguagesLight test`
- Screens per language: Home, Settings, My Bag, Swing, Hypothetical flight, Course, Performance, and Swing detail (empty). 72 images in total.
- Contact sheets per screen, taken after the fixes below, are in `Docs/Screenshots/reviewer-2026-10-27/` (`9-languages-light-<screen>.jpg`).

## Findings

| # | Screen | Languages | Problem | Status |
|---|---|---|---|---|
| L1 | Course | ja, es, pt-BR, fr, it | The club picker ("Select club") wraps onto two lines; Portuguese hyphenates it ("Selecio-nar"). | Fixed and re-captured: one line in all nine languages (`CourseView.swift`). |
| L2 | Course, Swing detail, every `SLMetricReadout` | all | An unavailable value reads "Unavailable" and then repeats "Unavailable" in its badge; on Swing detail it adds "n = 1". | Fixed and re-captured: the badge appears only for available values (`MetricReadout.swift`). |

No clipping, overflow, or untranslated text was found elsewhere. That covers Thai and Vietnamese diacritics, CJK line breaking, and long Romance-language labels in the tab bar and segmented controls.

## v6.0 §4 "strictly avoid" check (A2)

Checked against the 12-language screenshots and the camera code. None of these appear: neon gradients, glowing purple/blue, robot illustrations, emoji navigation, fake charts, unsupported AI scores, chatbot-style interfaces, decorative dashboards, or card grids. Glass effects come only from the system tab and navigation bars.

| Item | Finding | Status |
|---|---|---|
| Overloaded camera controls | With launch mode on, the camera panel showed controls that do nothing there: the exposure slider (the shutter and ISO are fixed) and the format menu (choosing a format would undo launch mode). Adding the live readout made this worse. | Fixed: both are hidden while launch mode is on (`CameraView.swift`). |
| Giant meaningless metrics | The Course distance readout is large even when it reads "Unavailable". It is the screen's primary value and states what is missing. | Kept. |

## Dark mode (30 Oct)

`testRemainingLanguagesDark` captured the eight screens in the nine languages. Contact sheets: `9-languages-dark-<screen>.jpg`.

- **First run:** stopped in French at Hypothetical flight. After scrolling, the "Driver example" row sat under the floating tab bar, so the tap landed on the bar.
- **Fix:** `reveal` now scrolls until the target's centre clears the tab bar. `SWINGLAB_LANGUAGES=fr,it,th,vi` reran the remaining languages, and they passed.

No new findings. Contrast holds: sage buttons carry dark text, and secondary text stays readable on the pine background. The only effect worth noting is system behaviour, not a layout bug: content scrolled under the glass navigation bar shows through it, e.g. the green Simulate button behind the Hypothetical flight title.

## Screens outside the main flow (30 Oct)

`testExtraScreensAllLanguages` captures the launch log and the add-club editor in all 12 languages, light and dark.

| # | Screen | Languages | Problem | Status |
|---|---|---|---|---|
| L3 | Launch log | es (pt-BR and vi fall back to an inline title) | The large title truncates: "Registro de lanzamien…". | Fixed and re-captured (en, ko, de, es, vi): inline title, as on Hypothetical flight (`LaunchLogView.swift`). |
| L4 | Add club | de | The sheet title truncates between Cancel and Save: "Schläger hin…". | Fixed and re-captured: "Neuer Schläger", and the title may shrink to 75 % instead of truncating (`ClubEditorView.swift`). |
| L5 | Add club | vi | The loft placeholder truncates: "Không bắt b…". | Fixed and re-captured: "Tùy chọn". |

Not reached yet in any language: camera (no camera in the simulator), live readout, launch measurement, catalog picker, and scorecard.

## Found while writing the club-management UI test (30 Oct)

| # | Screen | Device | Problem | Status |
|---|---|---|---|---|
| L6 | Add club, Hypothetical flight, hole score | all | Number and decimal pads have no return key, so once a number field had focus the keyboard could not be closed. On iPhone Duo (iOS 27.1) the open keyboard also kept the sheet's Save button out of reach. | Fixed: a Done button above the keyboard (`keyboardDoneButton`, `Theme.swift`). |
| L7 | Add club sheet | iPhone Duo, iOS 27.1 | After scrolling the form, the system hides the sheet's Cancel and Save until you scroll back to the top. | System behaviour; kept. The UI test scrolls back before saving. |
