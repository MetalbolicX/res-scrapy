# Plan 012: Consolidate DefaultsMerger from 234 lines to ~80

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 8e085f5..HEAD -- src/schema/v2/extractors/DefaultsMerger.res`
> If changed, compare excerpts below against live code.

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: LOW
- **Depends on**: 003 (extraction correctness — CountExtractor min/max removal should land first)
- **Category**: tech-debt
- **Planned at**: commit `8e085f5`, 2026-06-30

## Why this matters

`DefaultsMerger.res` has 8 merge functions (234 lines) that are structurally
identical: each switches on `defaultOpts → None | Some(def)`, then on
`fieldOpts → None | Some(opts)`, then builds a record with `pickOption` per
field. Only the record field names differ. Every new field type requires
copy-pasting another 15-line function. This plan consolidates them using a
generic merge approach, cutting ~150 lines and making field-type additions
trivial.

## Current state

### `src/schema/v2/extractors/DefaultsMerger.res` (234 lines)

8 identical-pattern functions:
- `mergeTextOptions` (lines 12-28) — 6 fields: trim, normalizeWhitespace, lowercase, uppercase, pattern, join
- `mergeHtmlOptions` (lines 30-43) — 3 fields: mode, stripScripts, stripStyles
- `mergeNumberOptions` (lines 45-62) — 7 fields: stripNonNumeric, pattern, thousandsSeparator, decimalSeparator, precision, allowNegative, onError
- `mergeBooleanOptions` (lines 64-82) — 5 fields: mode, trueValues, falseValues, attribute, onUnknown
- `mergeCountOptions` (lines 84-92) — 2 fields (or 0 after Plan 003)
- `mergeDateOptions` (lines 94-110) — 6 fields: formats, timezone, output, strict, source, attribute
- `mergeUrlOptions` (lines 112-129) — 7 fields: base, resolve, validate, protocol, stripQuery, stripHash, attribute
- `mergeJsonOptions` (lines 131-145) — 4 fields: source, attribute, path, onError

Each follows this exact pattern:
```rescript
let mergeXxxOptions = (fieldOpts, defaultOpts) =>
  switch defaultOpts {
  | None => fieldOpts
  | Some(def) =>
    switch fieldOpts {
    | None => Some(def)
    | Some(opts) =>
      Some({
        fieldA: ?pickOption(opts.fieldA, def.fieldA),
        fieldB: ?pickOption(opts.fieldB, def.fieldB),
        // ...
      })
    }
  }
```

The `resolveDefaults` function (lines 147-233) dispatches through
`FieldTypeVisitor` to call the appropriate merge function.

## Commands you will need

| Purpose   | Command                          | Expected on success |
|-----------|----------------------------------|---------------------|
| Build     | `pnpm run res:build`             | exit 0              |
| Tests     | `pnpm run res:test`              | all pass            |

## Scope

**In scope**:
- `src/schema/v2/extractors/DefaultsMerger.res` — consolidate merge functions

**Out of scope**:
- Changes to `FieldTypes.res` (type definitions)
- Changes to `FieldTypeVisitor.res` (dispatch pattern)
- Changes to `ExtractorRegistry.res` or any extractor
- Changes to `OptionsParser.res`

## Steps

### Step 1: Analyze whether ReScript allows a generic merge

ReScript's type system makes generic record merging difficult because each
record type has different fields. There are two approaches:

**Approach A: Keep individual functions but make them trivial (RECOMMENDED)**

Each merge function reduces to the same 3-line pattern if we extract the
"None-propagation" logic:

```rescript
let mergeFieldOpts = (fieldOpts: option<'a>, defaultOpts: option<'a>): option<'a> =>
  switch (defaultOpts, fieldOpts) {
  | (None, f) => f
  | (Some(_), None) => defaultOpts
  | (Some(def), Some(opts)) => Some(opts)  // field opts win entirely
  }
```

Wait — the current behavior is field-level merge (pickOption per field
inside the record). A simple "field opts win entirely" changes behavior.

**The current logic is**: if BOTH field-level and default-level options
exist, merge them field-by-field. This is important because a user might
set `defaults: {number: {precision: 2}}` and a field might have
`{stripNonNumeric: true}` — both should apply.

So the per-field `pickOption` IS necessary for correct behavior. The
functions can't be trivially collapsed without losing the merge semantics.

**Approach B: Use the FieldTypeVisitor to do the merge inline (RECOMMENDED)**

Instead of 8 separate functions, make `resolveDefaults` do the merge directly
in the visitor. Each visitor case handles its own merge:

```rescript
let resolveDefaults = (defaults: option<schemaDefaults>, fieldType: fieldType): fieldType => {
  let visitor: FieldTypeVisitor.fieldTypeVisitor<fieldType> = {
    text: opts =>
      Text(mergeTextOptions(opts, defaults->Option.flatMap(d => d.text))),
    // ... etc
  }
  FieldTypeVisitor.visitFieldType(visitor, fieldType)
}
```

This is what the current code already does (lines 148-232). The individual
merge functions ARE the repetition.

**Conclusion**: The individual merge functions cannot be generically replaced
because each merges a different set of record fields. The repetition is
inherent to ReScript's record types having different fields.

**What we CAN do**: Extract the common switch structure and reduce each
function to its minimal form. The current functions are already minimal
(they're just `switch` + `pickOption`). The "234 lines" includes comments
and the `resolveDefaults` dispatch.

### Step 2: Reduce repetition where possible

Since we can't eliminate the per-type functions, focus on reducing noise:

**2a.** Remove the `mergeCountOptions` function if Plan 003 removed the
`countOptions` type (or reduced it to empty).

**2b.** Extract a helper for the `None → fieldOpts | Some(def) → switch fieldOpts`
pattern. While we can't make the record construction generic, we can make
the outer switch reusable:

Actually, the outer switch IS already minimal:
```rescript
  switch defaultOpts {
  | None => fieldOpts
  | Some(def) => switch fieldOpts { | None => Some(def) | Some(opts) => Some({...}) }
  }
```

This is 5 lines per function. With 7 functions × 5 lines = 35 lines for
the outer structure, plus ~5 lines per record field × ~40 fields total =
200 lines. That's the 234 total.

**2c.** The real reduction comes from removing comments and tightening
the code. Remove the doc comments from individual merge functions (the
module-level comment already explains the pattern).

**REVISED DECISION**: This plan's ROI is lower than initially assessed. The
repetition is inherent to ReScript's type system. The best we can do:
- Remove dead code (countOptions if Plan 003 removed it)
- Remove verbose comments
- Slightly tighten the code style

**Do NOT attempt a generic merge** — it would require unsafe type casts
(`Obj.magic`) or metaprogramming, both of which are worse than the
duplication.

### Step 3: Clean up DefaultsMerger (reduced scope)

**3a.** If Plan 003 removed `countOptions` fields, remove `mergeCountOptions`
and update the visitor case for `count`.

**3b.** Remove inline comments from each merge function. The module-level
doc comment (lines 1-3) already explains the pattern.

**3c.** Ensure each function uses consistent formatting (2-space indent,
inline `Some(def)` matching).

**3d.** After cleanup, the file should be ~180 lines (down from 234, with
the count removal and comment stripping).

**Verify**: `pnpm run res:build && pnpm run res:test` → all pass.

## Test plan

- Existing `DefaultsMerger_test.res` tests must pass unchanged
- No new tests needed — this is a cosmetic cleanup with no behavior change

## Done criteria

- [ ] `pnpm run res:build` exits 0
- [ ] `pnpm run res:test` exits 0
- [ ] Dead `mergeCountOptions` code removed (if Plan 003 landed)
- [ ] File is under 200 lines (from 234)
- [ ] No behavior change (all tests pass unchanged)
- [ ] No `Obj.magic` or unsafe type casts introduced

## STOP conditions

- The cleanup changes behavior in any existing test — revert and report.
- ReScript v12 doesn't support the formatting changes — adjust to the
  compiler's formatting rules.

## Maintenance notes

- **The original finding overestimated the ROI.** ReScript's record types
  require per-field `pickOption` calls, and each options type has different
  fields. A truly generic merge would need ppx metaprogramming or unsafe
  casts, both of which are worse than the current duplication.
- The cleanup removes ~50 lines (comments, dead count code) rather than
  the originally estimated 150+.
- If the project adopts a ppx code generator in the future (e.g., a
  `@deriveMerge` annotation), revisit this plan.
- Added to "findings considered and rejected" in the index: the full
  consolidation is not worth the complexity in ReScript without ppx.
