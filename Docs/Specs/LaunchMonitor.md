# Launch Monitor mode — specification (for Round 4)

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
| **Spin rate / spin axis** | **Unavailable** | v6.0 §12; not observable at 240 fps from ball texture. |
| **Club head speed, smash factor** | **Unavailable** until club tracking (WP9) is validated | No wrist-speed proxy. |
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
