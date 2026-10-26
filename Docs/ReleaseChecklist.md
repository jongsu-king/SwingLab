# Release checklist

This is an outstanding release checklist, not a claim of TestFlight or App Store readiness. Checked against Apple's official documentation on 26 October 2026.

Apple currently requires uploads built with Xcode 26 or later and the iOS 26 SDK or later; its submitting page recommends Xcode 27 and announces iOS 27 SDK requirements for April 2027. Deployment minimum and build SDK are separate: this app's iOS 17 minimum does not replace the current SDK requirement. Use the latest stable Xcode available and re-check immediately before release. Sources: [Upcoming requirements](https://developer.apple.com/news/upcoming-requirements/) and [Submitting](https://developer.apple.com/app-store/submitting/).

## Before a device build

- Install full Xcode and iOS support; select it as the developer directory.
- Run the generated project's simulator build, all XCTest suites, and navigation tests. Fix any Swift 6 isolation, SDK availability, resource compilation, or persistence issues discovered.
- Configure a real development team and unique bundle identifier. No team, provisioning profile, signing certificate, App Store Connect record, or entitlements requiring an account have been created.
- Inspect the app icon and launch behavior on real devices; render every screen in light/dark appearances, landscape policy, large Dynamic Type, and VoiceOver.

## Physical iPhone validation

- Rear/front video orientation, mirror behavior, every offered resolution/FPS combination, actual output timestamps, slow motion, import and export.
- Denied/restricted permissions, camera interruptions, background/foreground transitions, missing media, low storage, canceled imports/analysis, thermal and battery behavior.
- Single golfer/multiple people, occlusion, stationary body, practice waggles, left/right-handed swings, camera motion, low light, missing wrists, and clips without a swing. Measure false phase suggestions; do not advertise clinical or radar-grade measurements.
- Fresh/stale/poor GPS fixes, negative/invalid accuracy, approximate location, GPS drift, pending shots, partial rounds, score editing, relaunch/recovery, and delete/restore behavior.
- Validate statistical region coverage using actual airborne carry/lateral shot data with known provenance. GPS displacement is not calibration truth for carry.
- All twelve translations need native-speaking golf terminology review and on-device layout review. Translated resources are not proof of successful localization QA.

## Public distribution

- Publish privacy policy and support information with the real publisher name and contact details. No fake contact address is included here.
- Review App Store privacy answers against the actual release binary and MapKit/system services. Required-reason manifest currently declares app-only UserDefaults (`CA92.1`) and local free-space checks that prevent failed recording (`E174.1`). Confirm these against [Apple's required-reason API documentation](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype) and generate Xcode's privacy report.
- Complete current age-rating questions, export-compliance answers, accessibility declarations, and regional distribution choices using actual app behavior.
- Produce real localized screenshots and metadata from the working signed app. Do not advertise ball speed, spin, complete ball tracking, validated hazard risk, or full 3D reconstruction.
- Archive, validate, upload to TestFlight, test the distribution build, resolve crashes and review findings, then submit. No archive, upload, deployment, or review has happened.

## Next engineering milestone

First obtain a successful native build and device-validated capture/pose/round core. Then expand biomechanical consistency, practice sessions, manual club/ball annotation, validated detector integration and observed-only tracer export. Calibrated launch/flight/spin research follows validated observability. Add licensed course geometry and weather only with explicit provenance and failure states. StoreKit can follow a useful stable release.
