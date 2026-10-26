# Capture, review, and pose analysis

## Implemented

- `SwingView` uses the host navigation stack, a SwiftData-backed library, real recording/import actions, confirmed deletion, and comparison navigation. Empty libraries contain no invented results.
- `CameraEngine` confines session/device/output mutations to a serial queue. It discovers rear/front wide-angle formats and offers 30/60/120/240 FPS only when a device format reports support. It selects a practical 1080p format when available, disables stabilization, and records a portrait, unmirrored, **silent** movie. Tap-to-focus/exposure, exposure bias, alignment grid, elapsed time, and a 60-second recording limit are connected to actual state. Permission denial opens system Settings. Session interruption, storage errors, background suspension, and cancellation after a permission prompt are handled.
- `ImportedSwingMovie` uses a file-based PhotosPicker transfer and copies the temporary provider file before returning. It requires no broad photo-library access. Video metadata validates a video track, finite positive duration, and the three-minute import limit. Files live in Application Support/SwingVideos. SwiftData stores only relative file names, recording metadata, and external Codable analysis data.
- Original-video export uses the iOS share sheet. AVPlayer supports 0.25×/0.5×/1× playback, exact seeks, and `AVPlayerItem.step(byCount:)` for real media-frame stepping. The displayed frame time comes from AVPlayer, not an assumed frame count.
- `PoseEstimationService` reads decoded frames asynchronously in an actor, retains no uncompressed frame history, uses source presentation timestamps, and limits inference to approximately 30 FPS. It maps all eight standard orientation/mirroring transforms into Vision's image orientation. Arbitrary transform matrices are rejected. Confidence filtering, conservative torso-based person continuity, timestamp-aware exponential smoothing, and explicit missing observations precede persistence. The pipeline stops on cancellation or critical thermal state.
- Skeleton/wrist overlays map normalized oriented coordinates onto the actual aspect-fit video rectangle. Paths do not bridge missing observations. Skeletons disappear when a nearby pose frame is unavailable.
- Conservative wrist-motion rules may propose address/top/impact **estimates**. These are unvalidated candidates, not detected ball impact. All eight phases can be set or cleared by the user, even without Vision results. Manual markers must remain chronological. Reanalysis preserves human edits. Tempo reports propagate estimated provenance unless all three required markers are manual.
- Head movement is a normalized 2D nose-displacement proxy between marked address and impact; no physical distance, 3D anatomical interpretation, or quality score is assigned.
- `SwingComparisonView` aligns two movies at their impact markers or clip starts, uses a common host-clock playback deadline, supports slow speed, frame step, a manual offset, side-by-side/opacity overlay, and pose paths. Different/unknown camera angles show a warning. Comparisons use matching-angle recorded timing only. Optional AVSpeechSynthesizer reads localized observations if an appropriate voice exists; otherwise text remains available.
- Deletion stages a movie before saving its database deletion. A failed save restores the movie. Failed final file erasure is reported and the staged file remains inside SwingVideos for a full local-data deletion retry.

## Validation actually performed

`zsh Scripts/check_capture.sh` passed nine model checks covering actual timestamp tempo, manual/estimated provenance, Codable round trip, invalid/nonfinite/missing timing, and head-proxy observations. The script extracts the actual value-type declarations from `SwingRecording.swift`; it does not compile the SwiftData model macro.

Shared AVFoundation/Vision/Transferable services passed Swift 6 typechecking against the installed macOS 14-compatible SDK. Generated landscape, portrait, and mirrored blank H.264 movies were actually decoded through Vision and correctly returned no reliable pose. A corrupt movie was rejected. These are macOS negative-path integration tests, not evidence of iPhone camera performance or successful golfer tracking.

All capture/review Swift files passed `swiftc -frontend -parse`. Full iOS typechecking, SwiftData migration/persistence integration, simulator UI checks, and physical-device capture tests remain unperformed because Xcode/iOS SDKs and the SwiftData macro plugin are absent from this environment.

## Known limits and required device checks

- This milestone is portrait-only capture. Hardware format support does not prove sustained FPS; inspect output timestamps on physical iPhones under realistic lighting and thermal conditions.
- No microphone track is recorded. Imported audio is preserved; comparison playback is muted.
- At most one golfer and one swing per clip should be analyzed. Person continuity is a heuristic and can fail with occlusion or other people. Confidence threshold 0.35 and smoothing time constant 45 ms are engineering defaults requiring calibration.
- Inference is sampled; high-frame-rate files retain their original frames for review but are not all analyzed. Temporal smoothing can shift estimated events. No impact-accuracy claim is supported.
- Vision observation geometry and transform correctness need positive golfer fixtures, especially mirrored and slow-motion Photos exports. The negative integration fixtures validate decoding/error paths, not landmark accuracy.
- Seek/frame stepping and common-clock comparison require device testing for variable frame rate, edited slow-motion movies, unusual media start times, codec failures, and buffering. Matching camera placement remains a user responsibility.
- Startup reconciles staged deletions against saved recording references: referenced files are restored, and files whose deletion committed are erased. Portable filesystem recovery tests pass; interrupted SwiftData transactions still require device validation. Active imports block full deletion until their transfer/save completes. A failed import/save cleanup can still leave an orphan movie; full data deletion includes the whole video directory.
- Club/ball detection, annotated object tracking, shot-tracer export, launch measurements, carry, and spin are unavailable. No trained detector or spin-validation dataset is included.
- No background camera operation, cloud upload, or mandatory external hardware is used. OS backups follow the user's device configuration.

## References

- [Apple FileRepresentation](https://developer.apple.com/documentation/coretransferable/filerepresentation): copy provider files within the transfer callback.
- [Apple AVAssetReaderOutput](https://developer.apple.com/documentation/avfoundation/avassetreaderoutput): sample-copy behavior.
- [Apple VNDetectHumanBodyPoseRequest](https://developer.apple.com/documentation/vision/vndetecthumanbodyposerequest): on-device body landmarks.
