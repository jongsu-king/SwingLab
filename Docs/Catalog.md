# Equipment catalog — Round 4

This is a growing lookup catalog, **not a complete inventory of every golf club since 2000**. The bundled file contains 1,515 model/edition records, 93 shaft identities and 17 named hosel generations across all 23 requested brands. Of the club records, 814 have a checked source and 701 are explicitly `verified: false`. Unverified model names/years are clearly labelled in the picker and have no stock loft or iron-set specifications. Coverage counts are inventory counts, not proof of completeness or accuracy.

Catalog IDs are immutable strings. A model reissued in another year has a distinct identity. `releaseYear` uses the source's model year where only a model-year table is available; announcement and first retail dates can differ by region. Variant arrays represent explicitly known variants, not all possible editions. Source URLs are checked research links; brand/model names are facts and are not translated. No marketing prose or images are bundled.

## Coverage by brand and category

Each cell is **total / sourced**; `0 / 0` means no records, not evidence that the brand never sold that category. Every row still needs historical/regional and variant reconciliation. The table is generated from `equipment-catalog.json`.

| Brand | Driver | Fairway | Hybrid | Utility | Iron sets | Wedge | Putter | Year span |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| TaylorMade | 57 / 38 | 32 / 25 | 25 / 13 | 8 / 0 | 51 / 33 | 10 / 4 | 9 / 4 | 2000–2026 |
| Callaway | 62 / 50 | 35 / 32 | 27 / 22 | 4 / 0 | 54 / 39 | 9 / 2 | 0 / 0 | 2000–2026 |
| Titleist | 42 / 23 | 26 / 14 | 22 / 11 | 6 / 0 | 64 / 39 | 13 / 11 | 0 / 0 | 2000–2026 |
| PING | 32 / 21 | 24 / 17 | 16 / 14 | 5 / 0 | 46 / 33 | 10 / 5 | 10 / 2 | 2000–2026 |
| Cobra | 41 / 25 | 20 / 16 | 19 / 15 | 3 / 0 | 37 / 30 | 4 / 1 | 4 / 0 | 2002–2026 |
| Mizuno | 23 / 17 | 11 / 9 | 10 / 5 | 7 / 0 | 51 / 22 | 12 / 0 | 2 / 0 | 2000–2026 |
| Srixon | 24 / 13 | 7 / 5 | 7 / 5 | 6 / 0 | 32 / 17 | 0 / 0 | 0 / 0 | 2003–2026 |
| Cleveland | 18 / 12 | 8 / 4 | 8 / 4 | 0 / 0 | 16 / 6 | 18 / 6 | 5 / 1 | 2000–2025 |
| PXG | 21 / 19 | 10 / 8 | 9 / 7 | 3 / 0 | 17 / 10 | 4 / 1 | 4 / 0 | 2015–2026 |
| Honma | 10 / 5 | 6 / 2 | 6 / 2 | 0 / 0 | 7 / 1 | 2 / 0 | 0 / 0 | 2013–2026 |
| XXIO | 16 / 3 | 6 / 3 | 6 / 3 | 0 / 0 | 8 / 3 | 0 / 0 | 0 / 0 | 2000–2026 |
| Wilson | 13 / 4 | 7 / 3 | 6 / 2 | 1 / 0 | 18 / 4 | 2 / 0 | 1 / 0 | 2001–2026 |
| Bridgestone | 6 / 0 | 4 / 0 | 3 / 0 | 0 / 0 | 10 / 0 | 3 / 0 | 0 / 0 | 2005–2022 |
| Tour Edge | 22 / 16 | 17 / 13 | 11 / 11 | 1 / 0 | 17 / 16 | 1 / 0 | 0 / 0 | 2005–2026 |
| Yamaha | 9 / 0 | 3 / 0 | 2 / 0 | 0 / 0 | 5 / 0 | 0 / 0 | 0 / 0 | 2013–2023 |
| Ben Hogan | 1 / 0 | 1 / 0 | 1 / 0 | 1 / 0 | 8 / 0 | 3 / 0 | 0 / 0 | 2000–2022 |
| Miura | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 13 / 7 | 2 / 0 | 2 / 0 | 2007–2025 |
| Epon | 7 / 0 | 3 / 0 | 0 / 0 | 2 / 0 | 13 / 0 | 2 / 0 | 0 / 0 | 2006–2023 |
| Odyssey | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 22 / 6 | 2000–2025 |
| Scotty Cameron (Titleist) | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 17 / 0 | 2000–2025 |
| Bettinardi | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 9 / 0 | 2000–2024 |
| Evnroll | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 11 / 0 | 2016–2024 |
| L.A.B. Golf | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 8 / 0 | 2018–2025 |

## What is still missing

- Every brand needs further historical verification. The 2000–2008 years are particularly incomplete in checked sources. Regional, women’s, junior, tour-only, limited-finish, left-handed and reissued models are not exhaustively cataloged. Existing family rows and separately sourced variants may coexist until reviewed; stable saved IDs will not be discarded during that review.
- Honma, XXIO, Yamaha, Ben Hogan, Miura and Epon need much deeper regional archive coverage. Their sparse older names are labelled unverified. Specialist putter brands need shape, neck, finish and edition catalogs. Zero-count categories in the table remain unresearched.
- Exact available iron-set members are currently sourced only for **Titleist T200 (2021), 4–9/P/W**. The corresponding stock lofts are the manufacturer's list. Other sets stay unspecified rather than assuming 3–PW. Selecting a set with no verified members retains a custom club name that the user can edit.
- Stock lofts are deliberately sparse. No assumed “standard” loft, shaft, lie, length, weight or flex is filled in when a model is selected.
- Shaft lookup includes major requested graphite and steel brands. Fourteen rows have checked identity/specification sources; the remainder explicitly carry `verified: false`. Weight lists are published nominal classes or published raw weights, not promises that every listed flex exists at every listed weight. Selecting a shaft leaves the actual weight/flex blank for the user's configuration.
- Adapter generation **names are not compatibility guarantees**. Only the systems listed below have complete sourced position arrays. Other generation records have no positions; the app says they are not verified. Left-hand tables, TaylorMade older FCT/R11 generations, Callaway original/OptiFit3, PING generations, Cobra MyFly/FutureFit33, Mizuno Quick Switch, Srixon QTS generations and PXG need further primary-table transcription before numeric values can be shown. They are not silently mapped to another brand or generation.

## Sourced adapter tables

| System | Positions | Numeric convention / limits | Source |
|---|---:|---|---|
| TaylorMade M5 / M5 Tour, right-hand 4° Loft Sleeve | 12 | Lie deltas relative to the guide's 56° STD; face positive = closed. Intermediate printed dashes have separate ordinal IDs. No spin changes copied. | [M5 tuning guide, p. 2](https://www.taylormadegolf.com/on/demandware.static/-/Sites-TMaG-Library/en_US/v1774238911369/manuals/M5_Tuning_Guide.pdf) |
| Titleist SureFit driver/fairway, RH | 16 | 0.75° increments; effective loft with square face. Face-angle degrees unavailable. | [SureFit guide and RH chart](https://www.titleist.com/fitting/golf-club-fitting/surefit) |
| Titleist SureFit hybrid, RH | 16 | 1° increments; separate from driver/fairway. Face-angle degrees unavailable. | [SureFit guide and hybrid RH chart](https://www.titleist.com/fitting/golf-club-fitting/surefit) |
| Callaway OptiFit 2, RH | 8 | Four loft choices × N/D; D lie delta and face effect unavailable because no degrees are published in this guide. | [Callaway manufacturer guide, retailer-hosted](https://cdn.arenacommerce.com/golfwarehouse/Callaway%20Optifit%20Adjustability%20Guide.pdf) |

The user selects the exact system and position. Effective loft is base loft plus the published position delta, labelled **catalog base loft** or **user-entered base loft**. No effective value is shown for an unknown position/delta. These are equipment settings, never measurements of the user's launch.

## Research evidence

Research was performed with the web tool on 26 October 2026. [Catalog identity evidence](CatalogIdentityEvidence.json) records 763 exact model/year rows matched or added from [Callaway's manufacturer trade-in archive](https://www.callawaygolf.com/on/demandware.static/-/Sites-CGI-ItemMaster/en_US/RateCards/titu_rate_card_us.pdf), with page numbers. No prices are included. Names were normalized only for punctuation, repeated year labels and the already-known category suffix; ambiguous wrapped rows were omitted. We retained unverified years when the model-year table did not match rather than silently changing release dates.

Additional sources checked:

- [TaylorMade specifications by year](https://www.taylormadegolf.com.au/includes/content-homepage-product-specs.html?lang=en_AU): 2020–2024 named families/variants.
- [Titleist previous models](https://www.titleist.com/previous-models?modelyear=2000-2009) and [T200 2021 specifications](https://www.titleist.com/golf-clubs/irons/t200-2021).
- [Callaway 2024 Ai Smoke announcement](https://ir.callawaygolf.com/news-releases/news-release-details/callaway-golf-announces-new-paradym-ai-smoke-woods-and-irons), [2025 Elyte announcement](https://callawaymedia.com/wp-content/uploads/2025/01/Elyte-Press-Release-January2.pdf).
- [PING G440 announcement on PGA Tour](https://www.pgatour.com/article/news/equipment-report/2025/01/14/what-to-know-about-pings-new-g440-club-line).
- [Srixon ZX Mk II iron announcement](https://news.dunlopsports.com/news/srixon-unveils-the-all-new-zx-mk-ii-irons/s/668a306a-1478-4de1-be16-23e52b620fda), [Cleveland RTX 6 announcement](https://www.globenewswire.com/news-release/2023/01/09/2585527/0/en/cleveland-golf-introduces-all-new-rtx-6-zipcore.html).
- [Fujikura 2019 shaft collection](https://fujikuragolf.com/wp-content/uploads/2019/01/FUJI-2019-Shaft-Collection-Web.pdf), [Mitsubishi Tensei 1K Pro Blue](https://mitsubishigolf.com/products/tensei-1k-pro-blue), [Graphite Design DI](https://proschoicegolfshafts.com/category/tour-ad-di-woods-shaft/), [Aldila Rogue](https://www.aldila.com/rogue), [UST Recoil](https://www.ustmamiya.com/recoil-shafts/), [ACCRA TZ5/TZ6](https://accragolf.com/tz5-tz6/), [KBS Tour](https://kbsgolfxshafts.jp/products/kbs-tour.html), [KBS $-Taper](https://kbsgolfshafts.com/products/taper), [True Temper Dynamic Gold](https://www.truetemper.com/collections/true-temper-iron-shafts/products/dynamic-gold), [Nippon MODUS³ Tour120](https://nipponshaft.com/product/steel/steel_modus_120.php). Project X/LZ flex/weight entries use Titleist's T200 table.

## Application and persistence

Brand → category → year (descending) → model/variant selection and global case/diacritic-insensitive search are available in the bag editor. “Not in the list” remains available through the hierarchy, and every form field can be entered manually. Shaft mode is stock, catalog or custom; custom fields cover brand/model/flex, weight, torque, kick point and tip trimming. Club length is explicitly enabled by the user, edited in 0.25-inch steps and stored in meters. Mass is stored in kilograms. Swing weight, grip and lie are persisted.

`SwingLabSchemaV3` is frozen independently of the current models. V4 adds four optional GolfClub columns (stable club ID, variant/member, stable shaft ID, configuration JSON). V1→V2 and V2→V3 continue to use their frozen types; V3→V4 is an additive lightweight migration. V5 is reserved for the reviewer's launch-shot log. Historical personal values remain unchanged and all new fields default to unavailable.

Validation: `python3 Scripts/validate_catalog.py` rejects invalid/duplicate IDs, missing brands/categories, future years, broken cross-references, nonfinite units/ranges and unsourced numeric club/shaft/hosel specifications. Core tests cover search, sorting, SI conversion, quarter-inch steps and effective-loft prerequisites. Hosted tests cover V3→V4 preservation, equipment SI round trips, invalid input and loading the bundled catalog. Simulator results are recorded by device and runtime in `Docs/MilestoneReport.md`; this document does not independently claim a simulator pass.
