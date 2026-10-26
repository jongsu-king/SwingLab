# Swing phase detection (v2)

`SwingLabCore/SwingPhaseDetector.swift` estimates eight phase markers from 2D pose landmarks. The markers are **unvalidated heuristic estimates**: every marker is `.estimated`, names the rule that produced it, and carries an ordinal confidence. The confidence is not a probability.

## Signals

| Signal | Definition |
|---|---|
| Hands | Midpoint of both wrists; the single visible wrist when one is missing. |
| Height | Vision `y` in the oriented image. Up is positive. |
| Body scale *S* | Median distance from mid-shoulder to mid-hip over the clip. With no torso, no phase is estimated. |
| Hand speed | Displacement over a fixed ±20 ms baseline (at least one neighbor each side). Not computed across gaps. |
| Still | Speed < 0.3 *S*/s. A still run continues while speed < 0.45 *S*/s. |

Input frames come from `PoseProcessing.process`: zero-phase Savitzky–Golay smoothing, with gaps of one or two samples interpolated and flagged.

## Rules

| Phase | Rule ID | Definition |
|---|---|---|
| Top | `pose.handsHighestBeforeLargestDescent.v2` | Local maximum of hand height (±2 samples) followed within 0.6 s by the largest descent in the clip. The descent must be ≥ 0.8 *S*. Refined by a three-point parabola limited to ±½ sample. A high finish cannot win because it is not followed by a large rapid descent. |
| Address | `pose.handsStillBeforeBackswing.v2` | Last sample of the still run (≥ 0.15 s) nearest before the top, with hands ≥ 0.8 *S* below the top. Waggles and a pause at the top are skipped. |
| Takeaway | `pose.handsReachHipHeight.v2` | Hands rise through mid-hip height between address and top. |
| Mid-backswing | `pose.leadWristReachesLeadShoulderHeight.v2` | Lead wrist rises through lead-shoulder height (a proxy for "lead arm parallel"). |
| Downswing | `pose.leadWristFallsToLeadShoulderHeight.v2` | Lead wrist falls through lead-shoulder height between top and impact. |
| Impact | `pose.handsLowestAfterTop.v2` | Lowest hands within 0.6 s after the top, refined like the top. A minimum at the window edge (clip ended mid-descent) is rejected. |
| Follow-through | `pose.handsReachShoulderHeightAfterImpact.v2` | Hands rise through mid-shoulder height within 1 s after impact. |
| Finish | `pose.handsStillAfterFollowThrough.v2` | Start of the first still run (≥ 0.2 s) within 1.5 s after follow-through. If the clip ends first, no marker. |

Crossings are linearly interpolated between samples and never across a gap. Markers that violate the physical order are dropped; a later rule cannot move an earlier phase.

## Confidence

confidence = base × density × (0.5 + 0.5 × observed fraction)

- **base:** 0.6 for crossings and impact. Address: 0.45 + still-run seconds, at most 0.8. Top: descent / (1.6 *S*), at most 0.9.
- **density:** 1.0 at ≥ 59 fps, 0.85 at ≥ 29 fps, otherwise 0.6.
- **observed fraction:** share of non-interpolated hand samples within ±0.1 s.

Markers below 0.3 are omitted. These weights are uncalibrated; they rank markers and cannot be read as accuracy.

## Measured behaviour on synthetic swings

Results from `Tests/SwingLabCoreTests/PhaseDetectionTests.swift`. Hands follow C1 cosine segments with known events: address end 1.0 s, top 1.9 s, impact 2.2 s.

| Condition | Result |
|---|---|
| Noise-free, single-sample wrist dropouts | Top and impact within 1.5 sample intervals at 30, 60, 120, and 240 fps. Crossing-based phases within 1 ms. |
| Address | Detected ≈ 0–21 ms after motion onset. A smooth onset has no sharp event, so a stillness threshold fires slightly late at every frame rate. |
| ±0.003 landmark noise | Top is noise-limited on the flat side of the peak: up to ≈ 24 ms **early** at 120–240 fps. Impact stays within ≈ 3 ms. The test tolerance is max(1.5 intervals, 30 ms). |
| Smoothing bias | Zero-phase smoothing of the asymmetric top (slow backswing, fast downswing) shifts it slightly toward the backswing side (≈ 5 ms at 240 fps). |
| Left-handed mirror | Identical timing. |

## Known limits

- The impact rule is a **hand-path low-point proxy**, not ball contact. Audio impact detection (WP3) is the intended refinement; the two are reported separately.
- Synthetic validation only. Real-swing accuracy needs labeled clips at several frame rates and camera angles; none exist yet.
- Camera angle is not used. Face-on and down-the-line both show the hands rising and falling, but the shoulder- and hip-height proxies are noisier down the line.
- Optional 3D pose (`VNDetectHumanBodyPose3DRequest`) is not implemented.
