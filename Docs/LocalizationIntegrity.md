# Localization integrity — Round 4

The localization gate checks the source of a key before checking its translations. This addresses review S4: a Core enum case such as `Provenance.measured.localizationKey` must require **Measured** in every supported locale even when the UI never passes that word as a literal to `text`.

## Typed boundary

[`LocalizationKey`](../Sources/SwingLabCore/LocalizationKey.swift) is a distinct type conforming to `ExpressibleByStringLiteral`. Its initializer accepts `StaticString`, not `String`; it has no interpolated-string, runtime-string, raw-value, or decoding initializer. [`AppPreferences.text` and `format`](../SwingLab/Core/Localization/AppPreferences.swift) require this type. UI helpers and Core enum label properties use the same type. Swift compilation therefore rejects passing a user-entered name, catalog model name, arbitrary error string, or assembled runtime key into those APIs.

Ordinary display values remain strings. Brand/model names and user content are displayed directly. UI messages use literal keys or typed mappings; variable content goes through positional format arguments. The distinction does not depend on whether a word happens to appear in the catalog.

## Source extraction

[`check_localizations.py`](../Scripts/check_localizations.py) tokenizes **every Swift file under both `SwingLab/` and `Sources/SwingLabCore/`**. It handles comments, escaped literals, balanced expressions, and declared argument labels. It collects a conservative superset of reachable keys: every typed enum case is checked, even if a particular runtime state never selects it.

The source roots include:

- Literal `text`/`format` arguments and typed helper arguments discovered from declarations, including labeled parameters and defaults. Helper names are not kept in a manually maintained allowlist.
- Stored and computed `LocalizationKey` properties, optional keys, assignments to typed state/error properties, and functions returning keys. Computed Core enum mappings and their switch branches are included.
- Typed collection literals and collection-returning functions, plus explicit `[LocalizationKey]` casts used by pickers.
- Typed struct fields used by synthesized memberwise initializers.
- Direct literal initializers for the listed SwiftUI text-bearing APIs. The product name `SwingLab` and numeric-only picker labels are deliberate exceptions.

The scanner rejects unresolved dynamic `text`/`format` inputs for any receiver name. It rejects interpolated keys, explicit `stringLiteral:` constructor calls outside the key implementation, and indirect localization method references such as `let translate = prefs.text`. Generic `ExpressibleByStringLiteral` factories outside the key implementation are prohibited: use a producer explicitly returning `LocalizationKey` instead. Implicit closure arguments such as `prefs.text($0)` are unresolved: write an explicit typed parameter, for example `(key: LocalizationKey) in prefs.text(key)`. Ternary/coalescing branches must each resolve to the supported typed boundary.

This is a constrained source-token audit paired with Swift typechecking, not a general Swift compiler or whole-program dataflow analysis. New key-producing syntax must receive an extraction/rejection regression before it is adopted. A successful catalog count alone is not evidence that an unsupported producer was analyzed.

## Locale and plural checks

The required locales are `en`, `ko`, `ja`, `zh-Hans`, `zh-Hant`, `es`, `pt-BR`, `de`, `fr`, `it`, `th`, and `vi`. Every extracted key must have a nonempty string unit marked `translated` in each locale. Missing keys fail as missing all 12 locales; missing one translation fails with the key and locale in the diagnostic.

Plural entries are validated even if no current source call reaches them. If any locale declares a plural entry, every locale must retain plural structure. Required grammatical forms are checked, including an empty plural dictionary; every supplied variant must have a nonempty translated string. The form sets agree with the cardinal categories in [Unicode CLDR's language plural rules](https://www.unicode.org/cldr/charts/49/supplemental/language_plural_rules.html):

| Locales | Required forms |
|---|---|
| `ko`, `ja`, `zh-Hans`, `zh-Hant`, `th`, `vi` | `other` |
| `en`, `de` | `one`, `other` |
| `es`, `pt-BR`, `fr`, `it` | `one`, `many`, `other` |

[`LocalizationPluralForms.json`](../Scripts/LocalizationPluralForms.json) supplies the count templates for swings, holes, shots, and practice sessions. Positional format placeholders retain each language's argument order.

[`build_localizations.py`](../Scripts/build_localizations.py) uses the same source extractor when merging translation fragments into `Localizable.xcstrings`. The independent checker validates the generated catalog rather than trusting the builder's zero-gap count. [`verify.sh`](../Scripts/verify.sh) runs the builder, checker, and regression suite before the build/test stages and fails on the checker's nonzero exit code.

## Regression checks

[`test_localizations.py`](../Scripts/test_localizations.py) contains **15 regression tests**. The first 12 cover:

1. A Core enum and nested UI helper; deleting the enum key's Korean translation must fail.
2. Unknown dynamic keys, including a fallback literal and string interpolation.
3. Both branches of a typed ternary initializer.
4. A newly added single-word Core enum key missing all 12 locales.
5. A plural entry missing a required grammatical form.
6. Explicit typed array options.
7. A typed memberwise struct initializer.
8. Annotated collections, collection-returning functions, and default key arguments.
9. An indirect reference to a localization method.
10. A direct SwiftUI literal key.
11. A locale whose plural structure is replaced by a plain string.
12. An explicit `stringLiteral:` constructor bypass.

Three further regression tests cover a memberwise initializer whose field is a collection of keys, a generic literal factory, and removal of a required `many` plural form. Independent review also exercises an implicit `$0` argument and a localization receiver named `app`, so these paths cannot rely on a special variable name such as `prefs`.

## Verification environment

Host: **macOS 27.0.1 (26A434), arm64. Simulator device: none. iOS runtime: none.** These are Python source/catalog checks; they do not run in a simulator and do not substitute for the two iOS test plans.

```sh
python3 Scripts/test_localizations.py
python3 Scripts/check_localizations.py
```

Actual output, preserved in [localization-integrity-macos.log](Logs/round-4/localization-integrity-macos.log):

```text
Ran 15 tests in 0.001s

OK
PASS localization source reachability: 617 literal/typed-enum/helper keys, 12 locales, plural forms; no unresolved text/format calls
```

The integration report separately names **iPhone 17 Pro / iOS 26.4** and **iPhone Duo / iOS 27.1** for iOS compilation and UI results. Runtime screenshot checks remain necessary for layout, text truncation, and linguistic quality; the source gate proves required entries exist within its supported source boundary, not translation quality.
