# Seeded club trace

The Club trace screen is available from Swing detail. The user first sets Address and Top markers, then taps the club head in the oriented address image. `VNTrackObjectRequest`, with `.accurate` tracking, follows a small seeded region through the backswing. Native movie presentation timestamps are retained; only value points and the current decoded image buffer are retained during tracking.

Tracking stops at the first Vision confidence below 0.5, invalid position, missing observation or timestamp gap over 100 ms. The threshold is an engineering stop rule, not a calibrated identity probability. It never reacquires after loss, extrapolates, or passes the Top marker. A tracked region can drift onto another object even at high confidence; physical-video validation remains necessary. No trained club detector is claimed. See [Apple VNTrackingRequest](https://developer.apple.com/documentation/vision/vntrackingrequest).

The displayed path is image-space, Vision-derived motion. Accepted observations draw a solid line; no missing observations are bridged. An orange ring identifies the last observed point after loss, with the loss timestamp shown. Playback and scrubbing expose the trace at the current movie time. The display does not produce club speed, ball speed, carry or impact timing. Traces are transient review results, not persisted measurements.

`SeededClubTrackTests` verifies permanent confidence-loss stopping, invalid-coordinate rejection, long-gap stopping and the Top boundary. These Core tests run on the macOS 27.0.1 (26A434) host (simulator device/runtime: none). App compilation and simulator checks are recorded with device/runtime in the main Round 4 report. No real-iPhone tracking accuracy is claimed.

Ball launch fitting remains exclusively owned by the reviewer's `LaunchTrackFitter`. No second ball fitter, ball-speed inference, ball detector or Kalman ball tracker was added. The reviewer API was absent during this implementation, so a ball-launch tracer adapter is pending its landing. This round implements seeded club tracking and the club tracer UI only; it does not claim full original v7 WP9 ball tracking/export acceptance.
