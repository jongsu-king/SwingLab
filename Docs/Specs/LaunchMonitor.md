# Launch Monitor mode — specification (for Round 4)

> How each readout value is computed, with formulas, constants, and worked numbers: [`Docs/Principles/LaunchReadout.md`](../Principles/LaunchReadout.md) (한국어: [`LaunchReadout.ko.md`](../Principles/LaunchReadout.ko.md)).

**Goal:** a TrackMan-style readout within about 2 s of each shot, using **one iPhone only**. Every number must be either measured honestly or labelled as what it is (v6.0 §2, §11–13).

## What one iPhone can and cannot provide

| Readout | Status in this mode | How |
|---|---|---|
| **Ball speed** | `visionDerived`, with confidence | Face-on, 240 fps, short shutter. The ball at address is the scale reference (42.67 mm diameter, sub-pixel circle fit). Track the ball centre in the first 2–5 frames after launch. Speed is the image-plane displacement × scale ÷ actual PTS deltas. |
| **Launch angle (vertical)** | `visionDerived` | Same face-on track: the angle of the fitted line through the first post-launch centres. Face-on puts the target line in the image plane. |
| **Launch direction (horizontal)** | `visionDerived`, **down-the-line setup only** | Only with a camera behind the ball; otherwise Unavailable. |
| **Impact time** | `audioDerived` (WP3) | Also the real-time trigger. |
| **Tempo / backswing / downswing** | estimated (WP2) | Pose phases. |
| **Carry** | `simulated`, shown as a **range** | `BallFlight` with measured speed and angle. Spin is unknown, so the result is computed across the user's club spin range (My Bag) or a documented typical range per club category. Never shown as a single precise number. |
| **Total** | `simulated`, shown as a **range** | Carry plus bounce-and-roll (`BallRoll`, `Docs/Physics.md`) for an assumed fairway, across the same spin bracket. Added 8 Nov 2026 at the user's request; never a measurement. |
| **Back spin** | `reference` (published bracket) | v6.0 §12: not observable at 240 fps from ball texture. The tile shows the cited spin bracket the carry is simulated across, badged "Reference — published averages". The golfer's own spin is never shown or stored. |
| **Club head speed** | `estimated` | No club observation. The tile shows the measured ball speed divided by the published smash-factor bracket for the club, badged "Estimated". Smash factor itself stays unavailable. |
| **Attack angle, club path, face angle** | **Unavailable** | Needs club-face observation that is not available. |

## Physics budget (why this can work, and when it cannot)

- **Displacement per frame at 240 fps.** Driver ball speed ≈ 74 m/s moves 31 cm per frame; 7-iron ≈ 54 m/s moves 22 cm. In portrait at 3 m (≈ 2.2 m field width, ≈ 0.49 px/mm at 1080 px), that is 100–150 px per frame. The ball stays in frame for about 3–5 frames, which is enough for 2–4 displacement pairs.
- **Scale error dominates.** A ±1 px error on a ≈ 21 px ball diameter is ±5 %. A sub-pixel circle fit over several address frames is required to reach ±2 %. Report the scale uncertainty in the confidence.
- **Motion blur.** At the default 1/240 s shutter a driver ball smears about 31 cm. Launch mode must set a **custom short exposure** (target ≤ 1/2000 s; ISO raised as needed). If the scene is too dark for that, the mode refuses: speed is Unavailable and the user is told why.
- **Depth.** Face-on with the target line parallel to the image plane keeps depth almost constant for the first frames. Warn if the ball's apparent diameter changes by > 5 % across the track (the ball is moving toward or away from the camera).

## Real-time pipeline

1. **Launch mode setup.**
   - Rear camera, 240 fps (refuse if unsupported).
   - Locked short exposure; focus locked on the ball.
   - Microphone on; portrait.
   - Phone on a stand about 3 m face-on.
2. **Ball lock.**
   - Auto-detect the ball at address: a small bright circle near the feet (Vision contours or a small Core Image filter).
   - The user confirms with a tap.
   - Then fit the scale.
3. **Ring buffer.**
   - Keep the last ~1.5 s of frames as pixel buffers (bounded memory, e.g. 360 frames at reduced resolution for the ROI), alongside continuous recording.
4. **Trigger.**
   - The `ImpactOnsetDetector` runs on streaming audio windows.
   - A transient while the ball ROI changes triggers analysis.
5. **Measure.**
   - Frame-difference the ball ROI after impact.
   - Detect the ball streak or blob centres in the next 2–5 frames.
   - Fit the line, then compute speed and angle with confidence.
   - Analysis must finish in **≤ 1 s** on device.
6. **Readout.**
   - A large, calm launch-monitor panel: ball speed, launch angle, carry range (simulated), impact time.
   - Each number carries its provenance badge.
   - Spin, club speed, and smash factor are shown as "Unavailable" (no blank tiles that imply future values).
7. **Session log.**
   - Each shot is saved with the video clip, the measured values, and confidence. It feeds My Bag carry statistics only as clearly labelled simulated values, never as measured carry.

## Core-first implementation (testable without a device)

- `BallScaleFitter`: sub-pixel circle fit of a ball blob, giving mm-per-px and uncertainty.
- `LaunchTrackFitter`: centres + PTS → speed, angle, residuals, confidence. Rejects tracks with fewer than 2 points, curvature inconsistent with ballistic flight, or diameter drift > 5 %.
- `CarryRangeEstimator`: speed + angle + a spin interval → min/max carry via `BallFlight`.
- **Tests:** synthetic rendered frames (a moving disk with blur and noise) at known speeds and angles. The AC is ±2 % speed and ±1° angle on synthetic data, which says nothing about real accuracy.

## Validation before advertising

- **Acceptance A22 / A23.** On ≥ 10 real shots recorded alongside a reference launch monitor (e.g. TrackMan at a range):
  - ball speed within ±3 %;
  - vertical launch within ±1.5°.
- **Until validated,** the mode is labelled **"Experimental"** in the UI, and no marketing copy may call it a launch monitor.

## Status (reviewer, 27 Oct 2026)

Core implemented in `Sources/SwingLabCore/LaunchMonitor.swift` and `LaunchMonitorImaging.swift`. They sit flat in the core folder, not in a `LaunchMonitor/` subfolder, because the portable check scripts glob only `Sources/SwingLabCore/*.swift`.

- **`BallScaleFitter`.** Partial-pixel area of the ball over ≥ 3 address frames gives a diameter, its SD, and mm/px.
- **`LaunchTracker.observe`.**
  - Takes the positive difference against the address frame, ahead of the ball and not below it, outside the vacated spot.
  - Picks the component nearest the predicted position.
  - Times each position at mid-exposure.
  - Refuses exposure > 1/1000 s.
- **`LaunchTracker.fit`.** A least-squares line gives speed (`visionDerived`, m/s) and angle (`visionDerived`, rad), with relative uncertainty and confidence.
- **`CarryRangeEstimator`.** `BallFlight` across the cited `ReferenceLaunchData.spinAssumption` gives a `simulated` shortest/longest carry. It returns nil for estimated speeds.

Synthetic results: 480×360 scene at 0.49 px/mm, 240 fps, 1/2000 s exposure, ball only.

| Shot | Speed result | Launch angle | Positions tracked |
|---|---|---|---|
| 54 m/s @ 16° | 53.95 m/s | 16.00° | 3 |
| 74 m/s @ 10.5° | 73.97 m/s | 10.50° | 2 |
| 40 m/s @ 24° | 39.98 m/s | 24.00° | 4 |

Reported uncertainty is about 1 %. **These numbers say nothing about real accuracy.** The synthetic scene has no club, no body, no rolling shutter, and no compression.

**Known gap:** the 7-iron carry range at 54 m/s / 16° is 188–190 yd. The cited spin interval is narrow (6,630–7,124 rpm, tour data), and the flight model overestimates iron carry (`Docs/Physics.md`). The range must not be presented as the user's expected carry until A22/A23 and the physics model are validated.

**Measure launch from a video (added 26 Oct, reviewer).** Swing detail → "Measure launch (experimental)" appears for recordings at ≥ 200 fps.
1. `LaunchVideoAnalyzer` finds the single clear impact sound (audio-derived).
2. It shows the frame 0.2 s before impact; the user taps the ball.
3. It fits the scale on 4 address frames, then tracks the first 6 frames after impact.
4. The result shows ball speed and launch angle (vision-derived), carry as a simulated range for a chosen club, and spin and club speed as Unavailable.

The shutter time of imported clips is unknown, so smear is limited by shape (over 4 diameters is refused).

**Untested on real video.** iPhone Camera slow-motion clips may arrive through the photo picker as a slowed 30 fps composition; the screen then refuses ("needs 200 fps").

**Live readout (added 27 Oct, reviewer).** Camera → Launch mode → "Live readout".
1. `CameraEngine.setLiveLaunch` adds an `AVCaptureVideoDataOutput` and an `AVCaptureAudioDataOutput` next to the movie output. If the session refuses either (rear camera, microphone, and launch mode are required), the toggle reports "unavailable".
2. "Set ball position" grabs one luma frame, turns it upright, and the user taps the ball and picks the direction.
3. `LiveLaunchCapture` copies only the launch region (`LaunchRegion`, shared with the video path) from the luma plane of each frame into a `FrameRing`. At 240 fps that is 139 frames (0.51 s, ≈ 48 MB for a 720 × 1280 view); crops stay in sensor orientation and only the 10 analysed frames are turned upright.
4. `StreamingImpactTrigger` checks each sound buffer: a first-difference peak 12 dB over the recent floor proposes a strike, and 60 ms later the full `ImpactOnsetDetector` confirms and times it on the last second of sound. Echoes within 1.5 s are ignored.
5. `LiveLaunchSession` waits for six frames after the strike and picks the four address frames (0.25…0.10 s before), then `LaunchPipeline` measures them off the capture queue. Audio and video timestamps share the capture session clock.
6. The panel shows ball speed and launch angle (vision-derived), carry as a simulated range for a chosen club, and the Experimental notice. Spin and club speed are not shown.

Core tests stream a synthetic shot as 1,024-sample sound buffers delivered 20 ms late and 240 fps sensor-orientation crops. The strike is timed within 1 ms, the frames are ready about 0.1 s after impact, and speed and angle match the recorded-video path (±2 %, ±1°). **Nothing about the device path is verified yet**: the clockwise turn assumes the rear camera's native landscape buffers, and whether a session accepts the data outputs beside a 240 fps movie output differs by device.

**Launch log (added 27 Oct, reviewer).** SwiftData V5 adds `LaunchShot` (lightweight migration from a frozen V4 snapshot). Each live readout is saved automatically, and a recorded-clip measurement can be saved with "Save shot". A shot stores ball speed (m/s) and launch angle (rad) with provenance, confidence, uncertainty, tracked positions, method, and the club chosen for the carry range. Carry is not stored. Swing → Ball Lab → Launch log lists the shots and a per-club average; the speed spread appears from 5 shots. "Delete all local data" removes them.

**Launch-monitor readout (added 8 Nov 2026, user request).** The user asked for the feature set of a
commercial iPhone launch monitor (ShotVision, as shown in an Instagram reel): six tiles, a setup
distance guide, automatic club choice, a session count, a range picture with a replay, flight-direction
and numbers-only toggles, and a spoken readout. Each is implemented so that the honesty rules hold.

- **`LaunchReadoutBuilder`** (`Sources/SwingLabCore/LaunchReadout.swift`) turns one `LaunchMeasurement`
  and a club into the six tiles. Ball speed and launch angle are passed through unchanged
  (`visionDerived`). Carry, total, and apex are brackets from five `BallFlight` runs across the cited
  spin bracket (`simulated`). Club speed is ball speed ÷ the published smash-factor bracket
  (`estimated`, `ReferenceLaunchData.smashAssumption`). Back spin is the bracket itself, with the new
  `Provenance.reference` case ("Reference — published averages"). The builder refuses estimated or
  user-entered speeds, so nothing downstream can promote a guess into a readout.
- **Total** uses `BallRoll` (`Sources/SwingLabCore/BallRoll.swift`): a tilted-bounce model with a
  speed-dependent restitution and a rolling deceleration for an assumed fairway (`TurfSurface.fairway`).
  `FlightResult` now reports `landingSpeed`. Unvalidated; see `Docs/Physics.md`.
- **Auto club** (`ReferenceLaunchData.nearestClub`): the club whose published (ball speed, launch) row is
  nearest, with a margin-based confidence that is not a probability. It only picks the spin bracket;
  the picker overrides it, and the readout says which club was chosen and why.
- **Setup check** (`LaunchSetupChecker`, `LaunchSetup.swift`): after the ball is tapped, the live path
  fits the ball on four address frames, reports the camera distance from the ball's apparent size and
  the lens field of view (`visionDerived`), and says **Too close** (fewer than 2.5 frames in view at
  80 m/s), **Ready**, or **Too far** (ball under 10 px). The ball is still re-fitted on every shot.
- **Strobe** (`LaunchStrobe`): the address frame and the six flight frames combined at their brightest,
  with the tracked centres marked. A picture of what was measured; the clip itself is still not saved.
- **Panel** (`LiveLaunchPanel`): session pills (clubs, shots), club menu with Auto, flight-direction
  toggle, numbers-only toggle, mute toggle, the setup row, the schematic range view (`LaunchRangeView`:
  dashed arc for the middle of the spin bracket, carry and total brackets on the ground, not to scale),
  the strobe, the six tiles (`LaunchReadoutGrid`), and a footnote saying what the non-measured tiles are.
  The same grid and range view appear on the recorded-clip screen; the launch log shows simulated
  carry, total, and estimated club speed per club average.
- **Voice** (`LaunchSpeaker`): ball speed, launch angle, and the carry bracket are spoken after each live
  shot in the app language (`launch.voice.*` templates). Spin and club speed are not spoken.
- **Session** (`LaunchSession`, `LaunchSession.swift`): the shots since the stream started, with per-club
  mean ball speed and launch (from two shots), the speed spread (from five), the simulated carry
  envelope, and the measured change from the previous shot with the same club. **Discard last shot**
  removes a mis-hit from the session and from the launch log. When the setup verdict is not Ready, the
  row also says where the camera could stand (`recommendedDistance`: the band where the ball is at
  least 10 px and stays in view for 2.5 frames at 80 m/s).
- **Flight scene and shot shapes** (second update, 8 Nov): `FlightSceneView` plays the simulated flight from
  behind the ball in real flight time, then the run (`FlightPlayback`). Live and recorded-clip shots are drawn
  straight along the target line with a note that a face-on camera cannot see the shape. Hypothetical flight
  gets a shot-shape preset picker (`ShotShape`, 13 shapes filling launch direction and spin axis), the scene,
  the classified shape (`ShotShapeClassifier`: start within 2° is on line; curve under 1.5 % of carry is none,
  under 6 % mild, else strong), and a simulated total. `Docs/Principles/LaunchReadout.md` §19.
- **Orientation:** the app stays portrait; the landscape layout of the reel was not adopted.
- **Tests:** `LaunchReadoutTests` (9) cover the roll bounds, the smash-factor estimate, the club guess,
  the readout invariants, the setup verdicts, the strobe, and the `reference` provenance round trip;
  `LaunchSessionTests` (3) cover the session averages, the change from the previous shot, and the
  recommended distance band; `ShotShapeTests` (3) the preset round trip through the flight model for both hands, the classification thresholds, and the playback. Core total: 100. The app side has not been built here (no Xcode on this machine); every app source
  was parse-checked and the localization, catalog, and project scripts pass.

**Not yet done:**
- Masking the club head and body near impact.
- Saving the clip around each live shot (values and the strobe are kept; the strobe is not persisted).
- On-device check of the live path: orientation, dropped frames, latency, the setup check, and the spoken readout.
- Validation against TrackMan, and of the roll model against measured totals.
