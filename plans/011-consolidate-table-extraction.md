# Plan 011: Consolidate table row-resolution logic

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 8e085f5..HEAD -- src/table/TableExtractor.res src/schema/v2/extractors/TableFieldExtractor.res`
> If changed, compare excerpts below against live code.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: 003 (extraction correctness — table header fix should land first)
- **Category**: tech-debt
- **Planned at**: commit `8e085f5`, 2026-06-30

## Why this matters

`TableExtractor` (standalone table mode) and `TableFieldExtractor` (schema
table field type) both resolve table rows using nearly identical logic
(`<tbody>` vs raw `<tr>` minus first). But they've diverged: `TableExtractor`
has `<thead>` header detection that `TableFieldExtractor` lacks. A bug fix
in one won't reach the other. Consolidating into a shared `TableUtils`
module eliminates double maintenance and closes the feature gap.

## Current state

### `src/table/TableExtractor.res` (lines 39-75) — header + row resolution

```rescript
      let headerEls: array<...> = {
        let fromThead = table->NodeHtmlParserBinding.querySelectorAll("thead th")
        if Array.length(fromThead) > 0 { fromThead }
        else {
          // No <thead> — take <th> cells from the very first <tr>
          switch table->NodeHtmlParserBinding.querySelector("tr")->Nullable.toOption {
          | None => []
          | Some(firstRow) => firstRow->NodeHtmlParserBinding.querySelectorAll("th")
          }
        }
      }
      // ...
      let rowEls: array<...> = {
        let fromTbody = table->NodeHtmlParserBinding.querySelectorAll("tbody tr")
        if Array.length(fromTbody) > 0 { fromTbody }
        else {
          let allRows = table->NodeHtmlParserBinding.querySelectorAll("tr")
          Array.slice(allRows, ~start=1, ~end=Array.length(allRows))
        }
      }
```

### `src/schema/v2/extractors/TableFieldExtractor.res` (lines 21-41) — row resolution only

```rescript
let resolveRows: (..., option<string>) => array<...> = (el, rowSelector) => {
  switch rowSelector {
  | Some(sel) => el->NodeHtmlParserBinding.querySelectorAll(sel)
  | None => {
      let tbodyRows = el->NodeHtmlParserBinding.querySelectorAll("tbody tr")
      if Array.length(tbodyRows) > 0 { tbodyRows }
      else {
        let allRows = el->NodeHtmlParserBinding.querySelectorAll("tr")
        if Array.length(allRows) <= 1 { [] }
        else { Array.slice(allRows, ~start=1, ~end=Array.length(allRows)) }
      }
    }
  }
}
```

**Key differences**:
1. `TableFieldExtractor` supports a `rowSelector` override; `TableExtractor` does not.
2. `TableFieldExtractor` checks `<= 1` before slicing; `TableExtractor` does not.
3. Neither checks for `<th>` before skipping the first row (Plan 003 fixes this for `TableExtractor`).

## Commands you will need

| Purpose   | Command                          | Expected on success |
|-----------|----------------------------------|---------------------|
| Build     | `pnpm run res:build`             | exit 0              |
| Tests     | `pnpm run res:test`              | all pass            |

## Scope

**In scope**:
- `src/table/TableUtils.res` (create) — shared row/header resolution
- `src/table/TableExtractor.res` — use `TableUtils`
- `src/schema/v2/extractors/TableFieldExtractor.res` — use `TableUtils`
- Test files: update imports if needed

**Out of scope**:
- Changes to `TableRunner.res` (thin facade)
- Changes to `ExtractionMode.res`
- Changes to the `columnField` or `tableOptions` types

## Steps

### Step 1: Create `src/table/TableUtils.res`

Create a shared module with row and header resolution functions:

```rescript
/** Shared helpers for resolving table structure (headers, rows).
  * Used by both standalone TableExtractor and schema TableFieldExtractor
  * to prevent logic divergence. */

open NodeHtmlParserBinding

/** Resolves header cells from a table element.
  * Order: <thead><th> → first <tr><th> → empty. */
let resolveHeaders: htmlElement => array<htmlElement> = table => {
  let fromThead = table->querySelectorAll("thead th")
  if Array.length(fromThead) > 0 {
    fromThead
  } else {
    switch table->querySelector("tr")->Nullable.toOption {
    | None => []
    | Some(firstRow) => firstRow->querySelectorAll("th")
    }
  }
}

/** Checks whether the first <tr> in a table contains <th> cells. */
let isFirstRowHeader: htmlElement => bool = table =>
  switch table->querySelector("tr")->Nullable.toOption {
  | None => false
  | Some(firstRow) => Array.length(firstRow->querySelectorAll("th")) > 0
  }

/** Resolves data rows from a table element.
  * Order: <tbody><tr> → all <tr> minus first (if header) → all <tr>.
  * ~rowSelector: when provided, overrides the default resolution. */
let resolveRows: (htmlElement, option<string>) => array<htmlElement> = (table, rowSelector) => {
  switch rowSelector {
  | Some(sel) => table->querySelectorAll(sel)
  | None => {
      let fromTbody = table->querySelectorAll("tbody tr")
      if Array.length(fromTbody) > 0 {
        fromTbody
      } else {
        let allRows = table->querySelectorAll("tr")
        if Array.length(allRows) <= 1 {
          []
        } else if isFirstRowHeader(table) {
          Array.slice(allRows, ~start=1, ~end=Array.length(allRows))
        } else {
          allRows
        }
      }
    }
  }
}
```

Create the `.resi` interface:
```rescript
open NodeHtmlParserBinding

let resolveHeaders: htmlElement => array<htmlElement>
let isFirstRowHeader: htmlElement => bool
let resolveRows: (htmlElement, option<string>) => array<htmlElement>
```

**Verify**: `pnpm run res:build` → exit 0 (module compiles).

### Step 2: Refactor TableExtractor to use TableUtils

In `src/table/TableExtractor.res`, replace lines 39-75:

```rescript
      let headerEls = TableUtils.resolveHeaders(table)
      // ... (header text extraction stays as-is)

      let rowEls = TableUtils.resolveRows(table, None)  // no rowSelector override
```

Remove the inline header/row resolution code. The existing header-to-text
mapping (lines 54-61) stays unchanged.

**Verify**: `pnpm run res:build && pnpm run res:test` → all pass.

### Step 3: Refactor TableFieldExtractor to use TableUtils

In `src/schema/v2/extractors/TableFieldExtractor.res`, replace the local
`resolveRows` function (lines 21-41):

```rescript
let rows = TableUtils.resolveRows(el, tableOpts.rowSelector)
```

Remove the local `resolveRows` function. The `TableUtils.resolveRows`
already handles `rowSelector` override and the `isFirstRowHeader` check.

**Verify**: `pnpm run res:build && pnpm run res:test` → all pass.

### Step 4: Verify behavior parity

Run the full test suite. Both `TableExtractor_test.res` and any
`TableFieldExtractor` tests should pass unchanged. The behavior is now
consistent between both paths.

**Key behavior change**: `TableFieldExtractor` now checks for `<th>` cells
before skipping the first row (it previously always skipped). This matches
the fix from Plan 003 for `TableExtractor`. If Plan 003 has not landed yet,
this plan also fixes Bug C.

**Verify**: `pnpm run res:test` → all pass.

## Test plan

- Existing `TableExtractor_test.res` tests must pass unchanged
- Existing table-field tests must pass unchanged
- If Plan 003 has not landed, add the `<tbody>`-less no-`<th>` test case
  from Plan 003 here as well (both paths now share the fix)
- Add a test that exercises `TableUtils.resolveRows` directly with a
  `rowSelector` override (TableFieldExtractor path)

## Done criteria

- [ ] `src/table/TableUtils.res` exists with `resolveHeaders`, `isFirstRowHeader`, `resolveRows`
- [ ] `pnpm run res:build` exits 0
- [ ] `pnpm run res:test` exits 0
- [ ] `TableExtractor.res` uses `TableUtils` (no inline row/header resolution)
- [ ] `TableFieldExtractor.res` uses `TableUtils.resolveRows` (no local `resolveRows`)
- [ ] Both paths use the same `isFirstRowHeader` check
- [ ] No behavior change in existing tests

## STOP conditions

- `TableFieldExtractor` needs the `resolveRows` function to have a different
  signature than `TableUtils.resolveRows` (e.g., it needs column-context).
  If so, add an optional parameter to the shared function instead of
  forking.
- `TableExtractor` uses a different element type (`NodeHtmlParserBinding.htmlElement`
  vs something else) — both should use the same type; if not, adjust the
  shared module's type signature.
- Circular dependency: `src/table/TableUtils.res` is imported by both
  `src/table/` and `src/schema/v2/extractors/`. Ensure `TableUtils` only
  depends on `NodeHtmlParserBinding`, not on either consumer.

## Maintenance notes

- After this plan, adding table-structure logic (e.g., `colspan`/`rowspan`
  handling) goes in ONE place: `TableUtils.res`.
- The `isFirstRowHeader` check is the critical behavior that was missing
  from `TableFieldExtractor`. The reviewer should verify that schema-based
  table extraction now correctly handles `<tbody>`-less tables without `<th>`.
