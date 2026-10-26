# Published launch reference data — Round 4

`ReferenceLaunchData` is a cited, offline reference dataset, not a trained model. It never predicts launch from body motion. `PublishedLaunchValue` deliberately cannot be confused with a personal `ProvenancedValue`: it retains the original number, unit, published standard deviation when available, source ID, table/page/column locator, publication year, and data year when known. An omitted field means unreported, not zero.

## Sources checked on 26 October 2026

| Source | Included rows | Verification and date interpretation |
|---|---:|---|
| [TrackMan May 2024 announcement](https://www.trackman.io/blog/introducing-updated-tour-averages), [PGA original poster](https://a.storyblok.com/f/117513/1920x883/6aefae601d/pga_tour-averages_trackman_blog.jpg), [LPGA original poster](https://a.storyblok.com/f/117513/1920x883/9617e89ecd/lpga_tour-averages_trackman_blog.jpg) | 12 PGA + 11 LPGA | Original publisher images downloaded and visually read. Data year is 2023; publication year is 2024. The LPGA 3-wood's printed spin is **2,595 rpm**, retained as printed. No correction based on expectations or another table. |
| [Older PGA attachment](https://support.trackmangolf.com/hc/en-us/article_attachments/7349802113051), [older LPGA attachment](https://support.trackmangolf.com/hc/en-us/article_attachments/7349801987483), linked by [TrackMan Support](https://support.trackmangolf.com/hc/en-us/articles/5089752464667-Shot-Analysis-Tour-Averages-On-PGA-LPGA-Tour) | 12 PGA + 11 LPGA | PDFs downloaded and page 2 (yards) visually rendered with macOS PDFKit. The PDFs do not print a publication/data year, so both fields are explicitly nil and UI says older/undated. The Support page's 2022 creation and 2025 update are not presented as measurement dates. LPGA PDF text extraction includes hidden PGA text; the **visible LPGA table** controls transcription. |
| [USGA / R&A R22-01](https://www.usga.org/content/dam/usga/pdf/Equipment/R22-01%20Launch%20conditions%20of%20male%20and%20female%20golfers%20of%20different%20skill%20levels.pdf) | 20 | All driver/6-iron × female/male × published skill-group rows from tables 5–7, including reported SDs. Primary indexed table text was verified with the web tool; direct PDF download returned HTTP 403, so no visual-PDF verification is claimed. The title page says **May 2019** despite the R22 identifier. Data combines studies; no single observation year is invented. The male professional driver's apex is absent in the table and remains absent. |
| [USGA DI Golfer Performance Measurement, December 2023 update](https://www.usga.org/content/dam/usga/images/course-care/GolferExperience/DI_Golfer_Performance_Measurement%202023%20Update.pdf) | 4 | Primary indexed page 7 prose accompanying figures 8–9 explicitly states smash averages for grass/mat: 7-iron **1.33/1.41** and pitching wedge **1.18/1.21**. Direct download returned HTTP 403. Study collection spans 2021–2023; publication year is 2023, single data year unknown. Other fields remain missing. Regression slopes and total hitting distances are **not** relabelled as smash means or carry. |

There are **70 rows**, with up to seven cited fields each: club speed, ball speed, smash factor, launch, spin, carry, and apex. No marketing prose, source graphics, swing videos, or trained weights are bundled. Original table rounding is preserved: converting the yards column to metres may differ from the independently rounded metres column. Independent averages need not satisfy `mean(ball speed) / mean(club speed) == mean(smash)`; the published smash column is retained.

## Units, matching, and allowed uses

Original mph converts by exactly 0.44704 to m/s, yards by 0.9144 to metres, degrees by π/180 to radians, and rpm by 2π/60 to radians/second. Dimensionless smash uses unit `1`. Presentation honors independent app distance and speed preferences.

`match(club:population:ballSpeed:)` requires a finite positive speed in m/s whose provenance is measured or vision-derived. It never accepts user-entered carry, wrist speed, estimated, audio-derived, simulated, or unavailable evidence. Matching is by an explicitly selected reference club and population; no gender or handicap is inferred from speed. Linear interpolation sorts the same club/population's published rows by ball speed and uses its bracketing rows. There is no extrapolation. Missing endpoint values remain missing. Both citations and the min/max of the published endpoint averages accompany each interpolation; that bracket is not a confidence interval or personal prediction. A tour series with only one point matches only that point.

`spinAssumption(club:)` returns an optional cited envelope of the **published mean spin values**, with row IDs, SI range, and an explicit rpm conversion for `BallFlight`. This is an assumption for sensitivity calculations, not measured spin, individual spin bounds, or a calibrated coverage range. There is no arbitrary percentage expansion or guessed fallback. The precise reference club is required; utility irons, sand/lob wedges, and putters have no substitute row.

The My Bag **Club profile** shows saved user-entered carry beside a separate published-reference section. It offers speed-matched references only when personal measured/vision-derived ball speed is supplied. Published smash and launch appear together in a full-sentence gapping-context explanation that explicitly avoids predicting personal distances or recommending a club. All new UI keys have 12 translations in `Scripts/Localization-reference.json`.

## Reviewer integration boundary and remaining gaps

The reviewer's launch-monitor branch and launch-shot log are absent from this working tree. Their reserved files were not created or edited. `ClubProfileView(club:measuredBallSpeed:measuredLaunch:)` and `ReferenceLaunchData.spinAssumption(club:)` are ready to consume that API once it lands. Consequently, the current navigation correctly shows personal ball speed and launch as unavailable, and **no claim is made that the launch-monitor carry path already consumes these assumptions**. The existing hypothetical flight sheet remains explicitly user-entered and independent of reference averages.

USGA numeric transcription is verified against indexed primary-source text, not a downloaded visual PDF. A reviewer should recheck the source tables when direct access is available. Historical date uncertainty is explicit. These population averages do not establish personal flight accuracy, a club fitting recommendation, or valid spin intervals for arbitrary golfers.

## Verification

Host: **macOS 27.0.1 (26A434), Apple silicon; no simulator device or iOS runtime used for this Core-only command**:

```sh
swift test --filter ReferenceLaunchDataTests
```

Seven XCTest cases cover source/value/unit integrity, selected independent transcription anchors, SI conversion, exact endpoints, interpolation with cited endpoints, missing-value propagation, no extrapolation or mixed-population/club interpolation, personal-provenance gates, and spin envelopes. The actual output is in [reference-core-macos.log](Logs/round-4/reference-core-macos.log). iOS compilation and the iPhone 17 Pro/iOS 26.4 and iPhone Duo/iOS 27.1 suites are run by the integration agent and recorded in the Round 4 milestone report; this document does not substitute host tests for those runs.
