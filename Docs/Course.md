# Course, rounds and landing estimates

## Implemented

- Native iOS 17 SwiftUI MapKit course screen with satellite map, compass and scale. Search uses `MKLocalSearch` via the replaceable `GolfCourseRepository` protocol. Search results represent places only.
- Optional, foreground, one-shot Core Location requests. Permission is requested only after tapping the location control. No always-on permission, background tracking or location upload is implemented.
- User-entered ball position, target, green front/center/back, layup and hazard reference point. Map taps place references; dragging the target updates estimates. Hole references are stored locally in SwiftData. Hazard points are not treated as polygons.
- Visible GPS horizontal accuracy and timestamp. Shot logging rejects negative/over-30-meter accuracy, fixes more than 20 seconds old, and fixes more than 5 seconds in the future. These are engineering thresholds, not GPS accuracy guarantees. Finishing a shot requires a newer fix than its start.
- Offline 9/18-hole round records, incomplete rounds, per-hole scores, putts, penalties, fairway and green outcomes; scores start unknown. User-entered strokes are authoritative and already include putts/penalties. Logging shots never silently changes the scorecard.
- GPS shot start/end positions with separate timestamps and horizontal accuracy, stable club ID plus a name snapshot, hole/shot numbers, editable lie/shape/penalties/notes, shot deletion. A pending shot survives restart. Changing holes and finishing a round are blocked while a shot is pending.
- Round history and editing. A completed round may have unscored holes; aggregates identify the number of scored holes.
- Landing mean from the selected club's entered carry and lateral bias, projected along the ball-to-target bearing. Optional 50% and 80% bivariate Gaussian regions use entered forward/lateral standard deviations and correlation. The mathematical kernel is `SwingLabCore.GaussianDispersion`.
- Explainable club comparison minimizes squared mean target error plus a variance term. Variance weights are 2 (conservative), 1 (balanced) and 0.5 (aggressive). Clubs without both variability values are excluded instead of giving missing data an unjustified advantage.

## Provenance and limitations

GPS distance is great-circle start-to-end ground displacement, including any roll and GPS error. It is **not airborne carry**, and it does not update carry distributions. A short displacement relative to the sum of reported endpoint accuracy values is flagged. Reported horizontal accuracies are not combined as if they were independently calibrated normal standard deviations.

Club inputs are user-entered. Probability regions are conditional mathematical regions for that input distribution, not validated confidence claims about actual shots. They exclude GPS origin error, uncertain heading, wind, elevation, lie and post-landing roll. Entering approximate carry alone produces a mean marker, but no probability ellipse.

MapKit place search does not supply verified pars, greens, fairways, hazard polygons or out-of-bounds geometry. Pars start empty. Hazard probabilities, hazard intersections and genuinely safer alternative aim points are unavailable. The caddie compares clubs against the chosen target only and is labeled as a statistical estimate, not course-aware risk optimization. Map tiles and search require an internet connection; the app does not promise offline map caching.

Search is locked during an active round to prevent accidentally associating shots with another course. The round must be finished before selecting another course. A club name edited on an old shot clears its club ID to avoid attributing it to the wrong saved club. Deleting a club preserves shot history via its name snapshot.

## Validation

All owned Swift sources were parsed using the installed Swift 6.1.2 frontend. `zsh Scripts/check_course.sh` executes five groups for actual GPS fix gates, score validation and reference JSON round trips, and typechecks the shared CoreLocation/MapKit services against the macOS SDK. A separate shared MapKit SwiftUI snippet typecheck verified map reader conversion, target drag, map style and probability-overlay API signatures. These are not an application build. Pure mathematical tests run in the main project harness. The environment has Command Line Tools, not Xcode/iOS SDK, so full native iOS compilation, SwiftData macro expansion, simulator tests and physical GPS validation remain unverified. `SwingLabTests/CourseTests.swift` additionally covers SwiftData hole-specific reference persistence and must run under Xcode.

Before shipping, build with Xcode and exercise: permission denied/restricted/reduced accuracy; stale and future fixes; poor accuracy and small displacement; one pending shot across restart; deletion of pending shots; manual target drag at high latitude/antimeridian; invalid/empty score fields; database save failure; translation expansion/VoiceOver; 9/18-hole partial rounds; course search cancellation/offline state; and battery use on an actual iPhone. A VoiceOver coordinate entry editor and arbitrary multi-point hazards are not yet implemented.

Apple API references: [requestLocation](https://developer.apple.com/documentation/corelocation/cllocationmanager/requestlocation()) and [MapReader](https://developer.apple.com/documentation/mapkit/mapreader).
