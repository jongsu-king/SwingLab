# Round 3 findings — implementation response

The reviewer was right to reject a cross-runtime “all green” claim. The earlier evidence covered **iPhone Duo, iOS 27.1**; it did not establish compatibility with **iPhone 17 Pro, iOS 26.4**. This response distinguishes the reproduced failure, its cause, and the verification completed so far. `Docs/Acceptance.md` is unchanged; only the reviewer grants acceptance.

## R3-1 — Agree

The generated Debug settings omitted `ONLY_ACTIVE_ARCH=YES`. [The generator](../../Scripts/generate_project.py:42) now emits **YES for Debug and NO for Release**, including the generated project configurations. The fix is in the source generator, so regeneration preserves it.

After that change, the exact command below compiled, linked and executed the plan on **iPhone 17 Pro, iOS 26.4**, without architecture or other build-setting overrides. That baseline run then exposed the eight app assertion failures described in R3-5; it was not a successful whole-plan test run. [Baseline log](../Logs/round-4/baseline-iphone17pro-ios26.4.log).

```sh
xcodebuild -project SwingLab.xcodeproj -scheme SwingLab -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' -derivedDataPath ./DerivedData test
```

The later native app-test recovery run also succeeded without build-setting overrides, as recorded under R3-5. A separate manual click of Xcode’s Run button is not claimed by these command-line results.

## R3-2 — Agree

[Onboarding](../../SwingLab/App/OnboardingView.swift:28) now says: “Camera, microphone, and location access are requested only when you use them. No account required.”

The String Catalog has nonempty translations for all 12 supported languages: English, Korean, Japanese, Simplified Chinese, Traditional Chinese, Spanish, Brazilian Portuguese, German, French, Italian, Thai and Vietnamese. The eleven translated entries are maintained in [Localization-round4.json](../../Scripts/Localization-round4.json); English is the source sentence. The new typed-key/source-reachability checker also covers the onboarding call. This is a disclosure correction, not a new permission request or a claim of physical microphone validation.

## R3-3 — Agree on duplicate navigation; camera side effect not independently demonstrated

Home’s primary button now sets the selected tab to `.swing`. [HomeView](../../SwingLab/Features/Home/HomeView.swift:17) receives the selection binding from [AppRouter](../../SwingLab/App/AppRouter.swift:10). It neither pushes a second Swing library nor presents a camera from Home. Recording remains an action within the Swing tab.

[NavigationTests.testOnboardingAndFourTabs](../../SwingLabUITests/NavigationTests.swift:4) now taps `home.record`, checks that Swing is selected, checks that the Home action is no longer visible and no stop-recording control appeared, then returns to Home and checks that its primary action remains available. This regression passed on **iPhone 17 Pro, iOS 26.4** in the ongoing [full-plan log](../Logs/round-4/full-iphone17pro-ios26.4.log). That individual result does not imply that the whole plan or the second runtime has finished. The reviewer’s specific automatic camera presentation was not independently reproduced, so no separate cause is asserted for it.

## R3-4 — Agree

The marketing hero is removed. [HomeView](../../SwingLab/Features/Home/HomeView.swift) begins with Record & review, then conditionally shows the last real practice session, the active round, and one same-club/same-angle tempo trend with its sample count. The empty state contains a short title and an action-oriented sentence. Session/trend content reads cached analysis columns rather than decoding pose payloads, and the trend requires at least five values.

[Theme.swift](../../SwingLab/Core/DesignSystem/Theme.swift) now defines the requested type scale, spacing values, an 8-point radius and hairline strokes. This source change does not by itself establish a complete 12-language visual acceptance. The final **iPhone 17 Pro, iOS 26.4** screenshots and their review are recorded in the Round 4 milestone report when capture/QA finishes.

## R3-5 — Partially: app failures reproduced; the payload diagnosis and transient-alert assumption need correction

The baseline **iPhone 17 Pro, iOS 26.4** run reproduced **17 app tests with 8 assertion failures**. The final baseline output was:

```text
Test Suite 'SwingLabTests.xctest' failed at 2026-10-26 21:39:45.462.
	 Executed 17 tests, with 8 failures (2 unexpected) in 1.366 (1.371) seconds
```

The exact log contains both original migration-test failures at the assertions **after a deliberate edit and rollback** (then lines 80/81 and 162/163), and both regrouping failures. [Baseline log](../Logs/round-4/baseline-iphone17pro-ios26.4.log).

**Root cause:** the migrated payload already passed its exact 734-byte preservation assertion, and its summary values were present before the test’s deliberate edit. Clearing the markers then encoded the edited 633-byte report and cleared tempo. On iOS 26.4, raw `ModelContext.rollback()` did not restore those retained model values. The reported 633/734 mismatch was therefore an analysis-edit recovery failure, not evidence of external-storage byte-count variation or corrupt migration. The exact payload assertion remains appropriate and was not weakened.

Session regrouping showed the same class of problem: after rollback, the retained recording and relationship arrays still exposed the staged membership. Adding `processPendingChanges()` was tried and did **not** fix this runtime. The failed attempt is preserved in [development5, iPhone 17 Pro / iOS 26.4](../Logs/round-4/development5-iphone17pro-ios26.4.log); the new geometry regression independently demonstrated the same behavior for a simple JSON attribute. Apple documents [rollback](https://developer.apple.com/documentation/swiftdata/modelcontext/rollback()) as restoring committed state; the implementation now protects the app’s observable invariant explicitly rather than assuming that behavior is identical on both runtimes.

The production save boundaries now capture exact pre-edit values, abort on a failed save, restore the captured values and rethrow the error:

- [AnalysisPersistence](../../SwingLab/Core/Persistence/AnalysisPersistence.swift:18) preserves the original payload and all cached analysis-summary values together.
- [PracticeSessionStore.saveChange](../../SwingLab/Core/Persistence/PracticeSessionStore.swift:11) restores the recording memberships, both sides of session relationships, and session attributes.
- [CourseGeometryStore](../../SwingLab/Core/Persistence/CourseGeometryStore.swift:6) restores the original point/polygon envelope and keeps the editor draft available for retry.

The regressions inject a throwing save through these same production boundaries. They verify exact restoration and persisted state instead of pretending that calling the operating system’s raw rollback now works on iOS 26.4. The snapshot assignment is idempotent when a newer runtime has already restored a value.

**App recovery verification completed:** **iPhone 17 Pro, iOS 26.4**, 21 app tests, zero failures. [Recovery log](../Logs/round-4/recovery-iphone17pro-ios26.4.log).

```sh
xcodebuild -project SwingLab.xcodeproj -scheme SwingLab -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' -derivedDataPath ./DerivedData -only-testing:SwingLabTests test
```

```text
Test Suite 'SwingLabTests.xctest' passed at 2026-10-26 21:54:05.489.
	 Executed 21 tests, with 0 failures (0 unexpected) in 1.316 (1.323) seconds
Test Suite 'All tests' passed at 2026-10-26 21:54:05.489.
	 Executed 21 tests, with 0 failures (0 unexpected) in 1.316 (1.324) seconds
```

**Detail UI:** the reviewer’s alert failure did not reproduce in this round’s baseline: all eight baseline UI tests passed on **iPhone 17 Pro, iOS 26.4**, including `DetailScreenshotTests.testEmptyDetailVariants`. The test already treated the alert as optional. It now additionally asserts the persistent `swing.detail.videoUnavailable` empty state after optionally dismissing the alert, which tests the real user-visible invariant. See [the test](../../SwingLabUITests/ScreenshotTests.swift:94) and [the view identifier](../../SwingLab/Features/Swing/SwingDetailView.swift:67). The strengthened detail regression also passed individually on **iPhone 17 Pro, iOS 26.4** in the full-plan run.

The recovery command ended with `** TEST SUCCEEDED **`.

**Final two-runtime gate:** pending the completion of both full plans at the time this response was written. The required destinations are **iPhone 17 Pro, iOS 26.4** and **iPhone Duo, iOS 27.1**. Their command logs are [iPhone 17 Pro / iOS 26.4](../Logs/round-4/full-iphone17pro-ios26.4.log) and [iPhone Duo / iOS 27.1](../Logs/round-4/full-iphoneduo-ios27.1.log). Replace this pending statement only after each complete log reports its actual final result. The [Round 4 milestone report](../MilestoneReport.md) carries the final command/output evidence.

## Feedback for the reviewer

Keep the explicit device/runtime matrix. A pass on iPhone Duo / iOS 27.1 cannot stand in for iPhone 17 Pro / iOS 26.4. The generated-project command should remain free of architecture overrides, while tool warnings should be reported separately from compiler warnings.

For persistence findings, identify the assertion’s phase: seed, migration, deliberate edit, failed save or rollback. In this case, the initial migration assertions passed; the later recovery assertions failed. Calling this an external-storage-size issue would have encouraged weakening a valid invariant and missed the production defect. Injected save failures at the real production boundary give stronger evidence than a standalone raw rollback assertion.

Keep the screenshot test focused on stable UI states. An alert is transient and may vary by runtime; a persistent missing-video state is the behavior users need. Preserve explicit uncertainty for the camera-cover observation unless a reproducible trigger is captured.

Continue separating implementation and synthetic tests from real-device accuracy. These simulator results do not establish camera throughput, contact timing, tracking accuracy or surveyed course boundaries. Catalog coverage is explicitly incomplete, published averages remain reference context, and the reviewer’s launch-monitor files and next schema version remain reserved.
