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

## Still open for A2 / A15

- **Dark mode** in the nine added languages.
- **Screens not reached by the screenshot flow:** club editor, catalog picker, camera, live readout, launch measurement, launch log, and scorecard.

## v6.0 §4 "strictly avoid" check (A2)

Checked against the 12-language screenshots and the camera code. None of these appear: neon gradients, glowing purple/blue, robot illustrations, emoji navigation, fake charts, unsupported AI scores, chatbot-style interfaces, decorative dashboards, or card grids. Glass effects come only from the system tab and navigation bars.

| Item | Finding | Status |
|---|---|---|
| Overloaded camera controls | With launch mode on, the camera panel showed controls that do nothing there: the exposure slider (the shutter and ISO are fixed) and the format menu (choosing a format would undo launch mode). Adding the live readout made this worse. | Fixed: both are hidden while launch mode is on (`CameraView.swift`). |
| Giant meaningless metrics | The Course distance readout is large even when it reads "Unavailable". It is the screen's primary value and states what is missing. | Kept. |

## Dark mode and extra screens (in progress)

- **Extra screens.** `testExtraScreensAllLanguages` passes and captures the launch log and the add-club editor in all 12 languages, light and dark. Those images are not reviewed yet.
- **Dark mode.** `testRemainingLanguagesDark` failed in one language: the "Driver example" control on Hypothetical flight was not reachable by scrolling ("flight.driverExample"). Needs a look before the dark review can finish.
