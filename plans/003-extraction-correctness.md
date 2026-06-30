# Plan 003: Fix four extraction correctness bugs

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 8e085f5..HEAD -- src/extraction/SelectorExtractor.res src/schema/v2/extractors/CountExtractor.res src/table/TableExtractor.res src/schema/v2/parser/OptionsParser.res`
> If any in-scope file changed, compare excerpts below against live code.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `8e085f5`, 2026-06-30

## Why this matters

Four small correctness bugs across the extraction pipeline produce wrong
output or silently ignore documented options. Each is a 1–5 line fix. Together
they close the gap between what the schema docs promise and what the code does.

## Current state

### Bug A: Single-mode returns `[]` on no match

`src/extraction/SelectorExtractor.res:20-25`:
```rescript
  | Single =>
    switch Document.querySelector(ctx.deps.doc.documentOps, document, selector) {
    | None => Ok([])
    | Some(el) => Ok([extract(el)])
    }
```
When `Single` mode finds no element, it returns `Ok([])`. The caller
serializes this to `[]` — indistinguishable from a multi-mode zero-match.
Users expect `null` for single-mode no-match. The serialized output comes
from `stringifyStrings(contents)` which produces `JSON.stringify(["array"])`.

### Bug B: `countOptions.min`/`max` silently ignored

`src/schema/v2/extractors/CountExtractor.res:9-12`:
```rescript
let extract: (array<NodeHtmlParserBinding.htmlElement>, option<countOptions>) => option<int> = (
  els,
  _opts,     // ← min/max never read
) => Some(Array.length(els))
```
The `countOptions` type (in `FieldTypes.res`) has `min` and `max` fields.
They are documented in `docs/schema-guide.md` as validation hints. The
function ignores them entirely. Users can set `{"min": 1, "max": 5}` in a
schema and get zero effect.

**Decision for this plan**: Remove the fields from the type rather than
implement enforcement. The enforcement behavior (clamping? erroring?) is
ambiguous and undocumented, so implementing it risks breaking user
expectations. Removing the dead fields is safe and honest.

### Bug C: First data row dropped in `<tbody>`-less tables

`src/table/TableExtractor.res:66-74`:
```rescript
      let rowEls: array<NodeHtmlParserBinding.htmlElement> = {
        let fromTbody = table->NodeHtmlParserBinding.querySelectorAll("tbody tr")
        if Array.length(fromTbody) > 0 {
          fromTbody
        } else {
          // No <tbody> — take all <tr>s and skip the first (header) row
          let allRows = table->NodeHtmlParserBinding.querySelectorAll("tr")
          Array.slice(allRows, ~start=1, ~end=Array.length(allRows))
        }
      }
```
When there's no `<tbody>`, the code always slices from index 1, assuming the
first `<tr>` is a header. But if the table has no `<th>` cells (all `<td>`),
the first row is data and gets silently dropped.

### Bug D: `parseHtmlOptions` wildcard absorbs `None`

`src/schema/v2/parser/OptionsParser.res:30-33`:
```rescript
      let mode = switch dictGet(raw, "mode") {
      | Some("outer") => Some(Outer)
      | _ => Some(Inner)
      }
```
The `_` wildcard matches both `Some("inner")` (correct) and `None` (key
absent). When `"mode"` is absent from JSON, the code produces `Some(Inner)`
instead of `None`. This means `DefaultsMerger.pickOption` can never override
the mode at config level — the field-level `Some(Inner)` always wins.

## Commands you will need

| Purpose   | Command                          | Expected on success |
|-----------|----------------------------------|---------------------|
| Build     | `pnpm run res:build`             | exit 0              |
| Tests     | `pnpm run res:test`              | all pass            |
| Build+Test| `pnpm run release:check`         | exit 0 (build+test+bundle+date-check) |

## Suggested executor toolkit

- After changing `.res` files, the corresponding `.res.mjs` is regenerated
  by `pnpm run res:build`. Never edit `.res.mjs` files directly.
- Match existing test patterns: see `test/res/CountExtractor_test.res` and
  `test/res/TableExtractor_test.res` for structural examples.

## Scope

**In scope**:
- `src/extraction/SelectorExtractor.res` — Bug A (single-mode no-match)
- `src/schema/v2/extractors/CountExtractor.res` — Bug B (remove `_opts`)
- `src/schema/v2/types/FieldTypes.res` — Bug B (remove `min`/`max` from `countOptions`)
- `src/schema/v2/parser/OptionsParser.res` — Bug B (remove min/max parsing) + Bug D (html mode wildcard)
- `src/schema/v2/extractors/DefaultsMerger.res` — Bug B (remove `mergeCountOptions` min/max fields)
- `src/table/TableExtractor.res` — Bug C (header detection before slicing)
- Test files for each bug (update or add cases)

**Out of scope**:
- Implementing min/max count enforcement (removal only — see "Why this matters")
- Changes to `Main.res`, `UrlRunner.res`, or CLI parsing
- The `DefaultsMerger` consolidation (Plan 012)

## Steps

### Step 1: Fix single-mode no-match (Bug A)

In `src/extraction/SelectorExtractor.res`, change lines 20-25.

Current:
```rescript
  | Single =>
    switch Document.querySelector(ctx.deps.doc.documentOps, document, selector) {
    | None => Ok([])
    | Some(el) => Ok([extract(el)])
    }
```

The caller at line 49 serializes via `stringifyStrings(contents)`. For
single mode with no match, return `Ok([])` still — BUT the serialization
should produce `null` for single mode. The cleanest fix: change the
`Single` no-match branch to return `Ok([""])` is wrong (produces `[""]`).

**Better approach**: The `stringifyStrings` function produces a JSON array.
For single mode, returning `[]` produces `"[]"`. The correct behavior for
"single element not found" is `null` (the JSON value). But `stringifyStrings`
takes `array<string>`, so it always produces a JSON array.

**Actual fix**: Change the `Single | None` branch to return an explicit
error using the existing `NoMatches` pattern, OR document that single-mode
no-match returns `[]` (empty array) as the intentional signal. Given that
`Main.res` dispatches through `runSelectorMode` which calls
`OutputWriter.writeOutput`, and the caller cannot distinguish single vs
multi — the simplest behavior-preserving fix is:

Keep `Ok([])` for now but add a `null` output path. Actually, the simplest
correct fix is to make `runSelectorMode` handle the empty case specially:

In `src/extraction/SelectorExtractor.res`, change the `runSelectorMode`
function (line 44-49) to check for empty results in single mode:

Current:
```rescript
  switch extractElements(ctx, document, selector, extractMode, mode) {
  | Error(msg) => {
      ctx.io.err(AppError.toMessage(AppError.ExtractionError(msg)))
      ctx.io.exit(1)
    }
  | Ok(contents) => OutputWriter.writeOutput(ctx, options, ctx.deps.serialize.stringifyStrings(contents))
  }
```

Change to:
```rescript
  switch extractElements(ctx, document, selector, extractMode, mode) {
  | Error(msg) => {
      ctx.io.err(AppError.toMessage(AppError.ExtractionError(msg)))
      ctx.io.exit(1)
    }
  | Ok(contents) =>
    switch (mode, contents) {
    | (ParseCli.Single, [||]) =>
      OutputWriter.writeOutput(ctx, options, "null")
    | _ =>
      OutputWriter.writeOutput(ctx, options, ctx.deps.serialize.stringifyStrings(contents))
    }
  }
```

This makes single-mode no-match output `null` instead of `[]`.

**Verify**: `pnpm run res:build && pnpm run res:test` → all pass.
If existing tests assert `[]` for single no-match, update them to expect `null`.

### Step 2: Remove dead `countOptions.min`/`max` fields (Bug B)

**2a.** In `src/schema/v2/types/FieldTypes.res`, find the `countOptions`
type definition. It currently looks like:
```rescript
type countOptions = {
  min: option<int>,
  max: option<int>,
}
```
Remove both fields, leaving:
```rescript
type countOptions = {
  // No configurable options currently; type exists for future use
}
```
If ReScript disallows empty record types, remove the type entirely and
update all references from `option<countOptions>` to `unit` or remove the
parameter.

**2b.** In `src/schema/v2/parser/OptionsParser.res` (lines 112-121), remove
the min/max parsing:
```rescript
let parseCountOptions: {..} => option<countOptions> = fieldJson => {
  switch dictGet(fieldJson, "countOptions") {
  | None => None
  | Some(raw) => {
      let min = dictGet(raw, "min")
      let max = dictGet(raw, "max")
      Some({?min, ?max})
    }
  }
}
```
If the type is removed, remove this function entirely and return `None` or
a constant. If the type is kept as empty, simplify to:
```rescript
let parseCountOptions: {..} => option<countOptions> = _ => None
```

**2c.** In `src/schema/v2/extractors/DefaultsMerger.res` (lines 84-92),
simplify `mergeCountOptions` accordingly.

**2d.** In `src/schema/v2/extractors/CountExtractor.res`, the `_opts`
parameter can be removed or kept as `option<unit>`.

**2e.** Update `test/res/CountExtractor_test.res` — remove any test cases
that set `min`/`max`.

**Verify**: `pnpm run res:build && pnpm run res:test` → all pass.

### Step 3: Fix first-row detection in `<tbody>`-less tables (Bug C)

In `src/table/TableExtractor.res`, change lines 66-74.

Current:
```rescript
      let rowEls: array<NodeHtmlParserBinding.htmlElement> = {
        let fromTbody = table->NodeHtmlParserBinding.querySelectorAll("tbody tr")
        if Array.length(fromTbody) > 0 {
          fromTbody
        } else {
          // No <tbody> — take all <tr>s and skip the first (header) row
          let allRows = table->NodeHtmlParserBinding.querySelectorAll("tr")
          Array.slice(allRows, ~start=1, ~end=Array.length(allRows))
        }
      }
```

Change the `else` branch to check if the first row has `<th>` cells before
skipping:
```rescript
      let rowEls: array<NodeHtmlParserBinding.htmlElement> = {
        let fromTbody = table->NodeHtmlParserBinding.querySelectorAll("tbody tr")
        if Array.length(fromTbody) > 0 {
          fromTbody
        } else {
          // No <tbody> — check if the first row is a header (<th> cells)
          let allRows = table->NodeHtmlParserBinding.querySelectorAll("tr")
          if Array.length(allRows) == 0 {
            []
          } else {
            let firstRowThCount = switch allRows->Array.get(0) {
            | None => 0
            | Some(firstRow) =>
              Array.length(firstRow->NodeHtmlParserBinding.querySelectorAll("th"))
            }
            if firstRowThCount > 0 {
              Array.slice(allRows, ~start=1, ~end=Array.length(allRows))
            } else {
              allRows
            }
          }
        }
      }
```

**Verify**: Add a test case in `test/res/TableExtractor_test.res` with a
`<tbody>`-less table that has no `<th>` cells (all `<td>`). Assert the first
row IS included in the output. Run: `pnpm run res:test` → all pass.

### Step 4: Fix `parseHtmlOptions` wildcard (Bug D)

In `src/schema/v2/parser/OptionsParser.res` (line 30-33), change:

Current:
```rescript
      let mode = switch dictGet(raw, "mode") {
      | Some("outer") => Some(Outer)
      | _ => Some(Inner)
      }
```

To:
```rescript
      let mode = switch dictGet(raw, "mode") {
      | Some("outer") => Some(Outer)
      | Some("inner") => Some(Inner)
      | None => None
      | Some(_) => None
      }
```

This ensures that when `"mode"` is absent from JSON, `mode` is `None`, and
`DefaultsMerger.pickOption` can fall back to a config-level default. When
an unknown value is given, it falls back to `None` (config default or no
mode set) rather than silently defaulting to `Inner`.

**Verify**: `pnpm run res:build && pnpm run res:test` → all pass. If tests
assert that absent mode defaults to `Inner`, update them to reflect the new
behavior (absent → None → config default → Inner as ultimate fallback).

## Test plan

- **Bug A**: Add/modify test in `test/res/SelectorExtractor_test.res` (if
  it exists) or `test/res/MainE2E_test.res` — assert single-mode no-match
  outputs `null` not `[]`.
- **Bug B**: Update `test/res/CountExtractor_test.res` — remove min/max
  test cases.
- **Bug C**: Add test in `test/res/TableExtractor_test.res` — table with
  `<table><tr><td>A</td></tr><tr><td>B</td></tr></table>` → expect 2 rows.
- **Bug D**: Update `test/res/OptionsParser_test.res` — assert that absent
  `mode` key produces `None`, not `Some(Inner)`.

## Done criteria

- [ ] `pnpm run res:build` exits 0
- [ ] `pnpm run res:test` exits 0; updated tests for all 4 bugs pass
- [ ] Single-mode no-match outputs `null`
- [ ] `countOptions` type has no `min`/`max` fields (or is removed)
- [ ] `<tbody>`-less tables without `<th>` include the first row
- [ ] `parseHtmlOptions` returns `None` for absent `mode` key
- [ ] No files outside the in-scope list are modified

## STOP conditions

- The `countOptions` type is used in a way that requires `min`/`max` to
  exist (e.g., a test explicitly checks the fields). If so, implement the
  fields instead of removing them.
- Existing tests depend on single-mode no-match returning `[]`. If changing
  to `null` breaks >3 tests, STOP and report — the behavior may be
  load-bearing for downstream consumers.
- `FieldTypes.res` uses a record type that ReScript doesn't allow to be
  empty — in that case keep the type with a documentation comment.

## Maintenance notes

- Bug A's fix changes the public output shape for single-mode no-match
  (`[]` → `null`). This is a minor breaking change for anyone parsing the
  output programmatically. Document it in `CHANGELOG.md` under
  `[Unreleased]` → `BREAKING`.
- Bug D's fix may change the default HTML extraction behavior for schemas
  that previously relied on the wildcard. Reviewer should check
  `test/res/HtmlExtractor_test.res` for behavioral assumptions.
