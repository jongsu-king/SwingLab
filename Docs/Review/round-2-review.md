# Round 2 — implementation review (Round 3)

Reviewed `4dc9668..901da63` before starting the remaining feature work. Commands: `git log --oneline 4dc9668..HEAD` and `git diff 4dc9668..HEAD`, followed by focused source/test reads. Line references below identify the reviewed HEAD, before fixes.

Commits reviewed: `d72378f` (phases), `1b209c9` (audio), `f085c55` (physics), `d5cf75f` (flight UI), `6dc86c1` (build report), `dc9cda8` (coaching), and `901da63` (Round 3 instructions). The prompt is unchanged. Generated catalogs, project entries, permission declarations, harness additions, and documentation were included; no additional High/Blocker was demonstrated there.

## Numbered findings

### S1 — High — mixed sampling rates remove address/finish

`Sources/SwingLabCore/SwingPhaseDetector.swift:113–138`: the detector derives one median interval for a clip combining 30 Hz coarse sampling with a 240 Hz swing window. The dense samples dominate that median. A 30 Hz central speed baseline spans 66.7 ms, exceeding `0.04 + 2.5 / 240 = 50.4 ms`; speeds become nil in the coarse region. Address is omitted, making tempo unavailable even with a complete swing. The uniform-rate tests did not exercise the actual service's splice.

Fix: derive cadence locally and preserve continuity segments instead of applying a dense cadence to the whole clip. Regression coverage must pass the actual coarse/dense sampling pattern and reject long gaps. Implementation and final test evidence are recorded below.

### S2 — High — empty feedback asserts unsupported normality

`SwingLab/Features/Swing/SwingDetailView.swift:220–222`, `Sources/SwingLabCore/Coaching.swift:75–91`: `feedback.isEmpty` displays “Within your usual range for every timing and head measure.” The engine also returns an empty array when current metrics are unavailable, baselines have SD=0, or non-tempo metrics have fewer than five comparable samples. Thus no comparison can produce a claim that every measure is normal, without n.

Fix: expose per-metric comparison eligibility from Core, show evidence and n only for eligible comparisons, and use a neutral unavailable state otherwise. Tests cover missing metrics, insufficient data, a constant baseline, and a valid in-range comparison. The replacement makes no universal consistency claim.

### S3 — Medium — immediate ground contact is reported as unreachable

`Sources/SwingLabCore/BallFlight.swift:137`: accepted zero/negative launch angles at zero landing height start on the ground, but the landing predicate requires a previous position strictly above it. A downward shot runs to the 20 s timeout and throws `insufficientData`, which the UI describes as a landing height the ball never reaches.

Fix: return an immediate contact result (zero airborne carry/time) at the launch plane for a nonascending launch. Keep downhill flight possible when the target plane lies below launch. Add regression tests.

### S4 — Medium — localization verification has false negatives

`Scripts/build_localizations.py:23–52`: isolated extraction produces no key for `field("Humidity", ...)` or `prefs.text(Provenance.audioDerived.localizationKey)`, while it finds direct `prefs.text("Humidity")`. Only app sources are scanned; Core enum producers and interpolated coaching IDs are not resolved. A new helper key absent from translation fragments can silently pass verification.

The current Humidity entry has all 12 languages because the reviewer supplied it manually. A missing current production translation is **not demonstrated**. The integrity-check failure is demonstrated. Fix requires an auditable typed-key boundary and rejecting unresolved dynamic calls; another helper-name regex is insufficient. This is WP8 work, not a completed fix.

### S5 — Low — typed flight angle uses a non-SI unit

`Sources/SwingLabCore/BallFlight.swift:81`: `landingAngleMetric` stores degrees under `deg`, contrary to the typed metric SI contract. It renders correctly, so a visible numerical error is not demonstrated. Fix: use radians in the typed metric; retain the explicitly documented degree-based simulation API and let the existing `rad` renderer convert at presentation. Add a unit regression.

### S6 — Low — custom aerodynamic coefficients bypass validation

`Sources/SwingLabCore/BallFlight.swift:101–109`: input checks omit mutable/decodable aerodynamic coefficients. A caller can supply NaN or negative drag and receive timeout/nonphysical integration rather than `invalidInput`. The app uses a constant valid model, so an ordinary UI trigger is not demonstrated. Fix: validate finite nonnegative coefficients and a supported positive lift exponent; test malformed inputs.

### S7 — High — a dropout edge becomes an impact estimate

`Sources/SwingLabCore/SwingPhaseDetector.swift:158–161`: the lowest remaining hand sample in the post-top window is accepted without requiring observed samples on both sides. A 180 ms wrist dropout around contact still emits impact at a dropout edge. This is not a measured minimum and defeats the requirement to omit low-confidence phases.

Fix: preserve continuous hand-track segments and require an actual local minimum with contiguous neighbors; omit impact across the long gap. A synthetic dropout regression reproduced the old behavior and now requires nil.

### S8 — Medium — audio selection ignores the nearest-pose rule

`Sources/SwingLabCore/ImpactOnsetDetector.swift:67–89`: after ambiguity rejection the detector always times the strongest peak. With a 0.16-amplitude click at 2.21 s near the pose estimate and a louder 0.8-amplitude neighboring click at 2.28 s, it returns 2.27954 s. Both are inside the 120 ms pose gate, but WP3 requires the nearest candidate.

Fix: choose the candidate nearest the finite pose estimate while retaining comparable-peak ambiguity rejection, then evaluate that candidate's confidence. Regression expects about 2.2095 s. This change does not prove which golfer caused the sound.

### S9 — Medium — edited simulation inputs retain stale results

`SwingLab/Features/FlightSimulation/HypotheticalFlightView.swift:56`: after Simulate, changing launch or condition fields leaves the prior result visible underneath the new values. A displayed carry can therefore appear associated with inputs that never produced it.

Fix: invalidate the result whenever any input changes; recompute only on Simulate. Native UI execution remains pending a simulator runtime.

### S10 — Medium — unanalyzed recordings evict the coaching baseline

`Sources/SwingLabCore/Coaching.swift:70–74`: the latest-20 cap is applied before discarding recordings with no available coached metric. Eight valid baseline swings followed by 25 unanalyzed recordings produce “need more swings” despite the UI promising earlier analyzed swings.

Fix: exclude fully unavailable samples before the cap, with deterministic ordering for equal timestamps. `testUnanalyzedRecordingsDoNotEvictTheAnalyzedBaseline` expects the earlier eight valid samples and the correct shift template.

### Unproven investigation — imported audio timestamp discontinuity

`SwingLab/Services/AudioImpactReader.swift:41–55` appends PCM buffers using the first PTS as its origin. A discontinuous imported timeline deserves coverage, but the exploratory writer normalized timestamps and the composition fixture did not yield a readable audio track. The observed 100 ms difference therefore does **not** demonstrate a reader defect. No severity is assigned and no speculative production fix is retained. Obtain a verified edit-list fixture with inspectable per-buffer PTS before drawing a conclusion.

## Decisions Codex should check

1. **Relaxed phase AC — Partially.** A fixed landmark-noise amplitude and a flat extremum do not acquire more signal merely because frames arrive faster; a time-based noise floor is reasonable. However, one synthetic shape and deterministic noise seed do not establish that 30 ms is a general bound, or that the original AC is physically impossible for every estimator. The original tests also offset the expected address by 12 ms and use a separate 35 ms tolerance. Keep this as a disclosed synthetic engineering tolerance, not a passed original WP2 AC or real-swing accuracy claim. Mixed-rate regression is necessary in addition to uniform-rate tests.
2. **Impact definition — Partially.** The code measures a hand-path low point, not ball contact. Bias relative to contact is structurally possible because the input contains no ball or club contact observation. A systematic positive bias specifically caused by forward shaft lean is **not demonstrated** without synchronized labeled footage. Preserve estimated provenance and manual correction; an audio transient is additional evidence, not proof of the golfer's contact.
3. **Audio thresholds — Partially.** 12 dB candidacy, 6 dB ambiguity, confidence 0.5 (24 dB under the current mapping), and the 120 ms pose gate are explicit engineering defaults. Synthetic click/noise tests check implementation, not false-positive rates on driving ranges. The ambiguity rejection is sensible, but a high-SNR neighboring strike can still pass if alone in the gate. Neither calibrated probability nor contact accuracy is established. Retain documented limitations and require real audio/video labels before making accuracy claims.
4. **Onset bias — Agree, narrowly.** Do not hide an ad hoc 0.45 ms correction in the code based on a single click shape. Acoustic travel alone is about 2.9 ms/m, and camera distance is unknown. Preserve the movie timeline; document filter/window bias separately from acoustic travel and camera A/V synchronization. Synthetic codec checks do not validate every imported edit or device capture.
5. **Flight model — Partially.** Agree with rejecting fitting to the same TrackMan table used for validation. Disagree that secondhand coefficients with an omitted Reynolds term constitute a verified published model. The historical reference is now checked against TrackMan's own attachment; its driver landing angle is 38°, not the earlier documentation's 37°. Lyu et al. (2018), DOI `10.3390/proceedings2060238`, is a better primary-source model family: measured production balls, piecewise drag vs Reynolds number and quadratic lift vs spin ratio. It is ball-specific, and its measured spin range does not justify blindly extrapolating to a 7097 rpm iron. No universal replacement coefficient set is defensible from the material obtained. Keep the existing simulation experimental, preserve the documented carry/apex disagreement, and obtain model-specific coefficient data and independent trajectories before replacement. See `Docs/Physics.md` for primary links and scope.
6. **Localization gap — Agree.** S4 demonstrates the extractor miss. Manual entries repair today's known strings but cannot satisfy WP8's failure-on-missing-source-key requirement. There are also no plural variations in the reviewed catalog.
7. **Fixed ±20 ms hand-speed baseline — Partially.** It limits adjacent-sample noise amplification at high frame rates, but it is not exactly rate-independent (30 Hz still spans at least 66.7 ms). A single median cadence made its continuity gate incompatible with the real two-pass pipeline (S1). Keep the physical-duration intent, fix local cadence/continuity, and avoid an absolute rate-independence claim.

## Verification and implementation status

Baseline: iOS app build succeeded; all 47 Core XCTest cases passed; native unit/UI test targets compiled with `build-for-testing`. Full Xcode 27.1 is present, but `xcrun simctl list runtimes` returned an empty inventory. Simulator execution, migration on iOS, installation, launch, and screenshots are not claimed.

There were no Swift compiler warnings. The actual baseline build log contains an AppIntents metadata-extraction warning (“no AppIntents.framework dependency found”), so “0 warnings” is not an accurate literal description of this run.

Final fix and work-package verification is appended at the completed boundary.

## Feedback for the reviewer

Keep the two-way, evidence-based review and the prohibition on fitting validation data. Future prompts should distinguish an engineering tolerance from a changed acceptance criterion, and require a mixed-cadence service fixture rather than only constant-frame-rate synthetic tests. Empty algorithm output must not become an affirmative UI conclusion. The reviewer understated the unverified scientific-model status and overstated the “rate-independent” baseline; the forward-shaft-lean bias direction is still not demonstrated. Report compiler warnings separately from Xcode tool warnings. Provide labeled real swing/audio fixtures and a primary coefficient table if quantitative accuracy is the next acceptance gate.
