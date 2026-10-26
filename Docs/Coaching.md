# Coaching (WP4)

`SwingLabCore/Coaching.swift` turns a swing's cached metrics into **observations against the golfer's own recent swings**. The swing detail screen shows them under "Compared with your recent swings".

## Rules (`coach.baselineZ.v1`)

| Rule | Value |
|---|---|
| Comparable swings | Same camera angle, same club, analyzed **before** this swing, most recent first. Recordings have no club yet, so today the club is always "none". |
| Baseline size | Up to 20 swings. |
| Minimum | 5 comparable values for a metric. Below that, only "analyze N more swings" is shown (`coach.needMoreSwings`). |
| Values used | Only metrics whose provenance is not `unavailable`. Estimated, user-entered, and vision-derived values are all compared. The source labels stay on the metrics themselves. |
| Observation | `coach.<metric>.higher` / `.lower` when \|z\| > 1.5, where z = (value − baseline mean) / baseline SD. |
| Constant baseline | SD = 0 gives no observation, because one identical value cannot define "unusual". |
| Metrics | Tempo ratio, backswing seconds, downswing seconds, head displacement (normalized image units, shown as %). |

The text states the value, the baseline mean, and n. It never says good or bad, and never names a swing fault. The thresholds (5, 20, 1.5) are uncalibrated choices, not coaching evidence.

## Drills

Each observation may carry one drill ID. The list is intentionally short:

| ID | Text (English) | Used for |
|---|---|---|
| `drill.countedTempo` | Count "one-two-three" to the top and "one" down to impact for five swings, then record one and compare. | Tempo, backswing, downswing |
| `drill.steadyHeadMirror` | Make five slow swings keeping your head against a fixed reference line, then record one and compare. | Head displacement |

Both are common practice-range tempo and head-stability routines. They are offered as ways to produce comparable recordings, not as prescriptions.

## Consistency

`CoachingEngine.consistency(_:in:)` returns n, mean, sample SD, and CV for a metric. It returns nil below 5 values.

## Not yet done

- **`PracticeSession` model.** Grouping recordings within 90 minutes needs a SwiftData schema V3 plus a migration test. It should be done with the simulator available.
- **Club on recordings.** Adding a club changes the baseline from "same angle" to "same angle and club".
- **Session-level consistency charts.** These belong in Performance.
