# Coaching (WP4)

`SwingLabCore/Coaching.swift` turns a swing's cached metrics into **observations against the golfer's own recent swings**. The swing detail screen shows them under "Compared with your recent swings".

## Rules (`coach.baselineZ.v1`)

| Rule | Value |
|---|---|
| Comparable swings | Same known camera angle and same stable club UUID, analyzed **before** this swing, most recent first. Unknown club is its own group; an unspecified angle cannot establish comparability. Fully unavailable samples do not evict analyzed samples from the last-20 cap. |
| Baseline size | Up to 20 swings. |
| Minimum | 5 comparable values for a metric. Below that, no observation is made; tempo may show `coach.needMoreSwings`, and other unavailable comparisons remain neutral. |
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

## Round 3 review correction

An empty feedback array does **not** mean that every metric is within the user's normal range: missing current values, fewer than five comparable values, and zero baseline SD can all prevent a comparison. `CoachingEngine.comparisons(for:history:)` now exposes only metrics actually compared, with their baseline n, mean, and SD. Swing detail shows those baseline means and n; when none can be compared it reports no comparison. It never infers an all-metrics normal result from an empty array. `CoachingTests.testEmptyFeedbackDoesNotImplyAValidComparison` covers missing data, constant baselines, n < 5, and a valid tempo baseline with the other three measures unavailable.

## Practice sessions delivered in Round 3

`SwingLabSchemaV3` stores sessions and an optional club UUID on each recording. New recordings capture the current handedness preference and auto-group within an inclusive 90-minute rolling inactivity window when club, camera angle, and handedness match. Existing recordings migrate without inventing handedness or club context. Users can regroup recordings and edit session notes/context; session dates derive from the earliest member. See [PracticeSessions.md](PracticeSessions.md).

Swing and Performance link to session details. The comparison selector separates club and camera angle, and the summary shows **n, mean, sample SD, and CV** for each available metric only when n ≥ 5. Unknown angles produce no consistency summary. The screen reads cached recording columns; it never decodes pose JSON for lists or aggregate statistics. These are numeric summaries, not a new chart or a claim of validated coaching efficacy.

Native iOS migration and persistence tests now run on iPhone Duo with iOS 27.1. Real-swing coaching thresholds and drill effectiveness remain uncalibrated.
