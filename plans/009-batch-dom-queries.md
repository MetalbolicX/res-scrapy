# Plan 009: Batch DOM queries to eliminate N+1 in extractors

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 8e085f5..HEAD -- src/schema/v2/executor/RowExtractor.res src/schema/v2/extractors/TableFieldExtractor.res`
> If changed, compare excerpts below against live code.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: perf
- **Planned at**: commit `8e085f5`, 2026-06-30

## Why this matters

Both `RowExtractor` and `TableFieldExtractor` issue DOM queries inside
nested loops: for each row, for each field, a `querySelector` or
`querySelectorAll` runs against the row subtree. For 1,000 rows × 20 fields,
that's 20,000 CSS engine evaluations. The fix is loop inversion: query each
field's selector across all rows upfront, then build output rows by index.
This is a pure performance optimization — no behavior change.

## Current state

### `src/schema/v2/executor/RowExtractor.res` (lines 48-107)

```rescript
  let results: result<array<JSON.t>, schemaError> = limitedRows->Iter.values->Iter.reduce((
    acc,
    rowEl,   // ← outer loop: per row
  ) => {
    // ...
        let fieldResult = resolvedFields->Iter.values->Iter.reduce((
          fAcc,
          (name, field, resolvedFieldType, nestedDefaults),  // ← inner loop: per field
        ) => {
          // ...
              let value = if isMultiElementType(resolvedFieldType) {
                let allEls = NodeHtmlParserBinding.querySelectorAll(rowEl, field.selector)  // ← R×M queries
                // ...
              } else {
                let maybeEl = NodeHtmlParserBinding.querySelector(rowEl, field.selector)  // ← R×M queries
                // ...
              }
```

### `src/schema/v2/extractors/TableFieldExtractor.res` (lines 88-160)

Same pattern: outer loop over `rows`, inner loop over `resolvedColumns`,
with `querySelector(All)(rowEl, col.selector)` per cell.

## Commands you will need

| Purpose   | Command                          | Expected on success |
|-----------|----------------------------------|---------------------|
| Build     | `pnpm run res:build`             | exit 0              |
| Tests     | `pnpm run res:test`              | all pass            |

## Scope

**In scope**:
- `src/schema/v2/executor/RowExtractor.res` — batch DOM queries
- `src/schema/v2/extractors/TableFieldExtractor.res` — batch DOM queries
- Test files: `test/res/RowExtractor_test.res`, `test/res/TableExtractor_test.res`
  (verify existing tests still pass; add scaling test if none exist)

**Out of scope**:
- `src/schema/v2/executor/ZipExtractor.res` — already batches correctly
- Changes to `ExtractorRegistry.res`
- Changes to the `ExtractionStrategy` functor

## Steps

### Step 1: Batch queries in RowExtractor

The key insight: instead of querying `querySelector(rowEl, field.selector)`
for each (row, field), we can pre-compute, for each field, an array of
elements across all rows. Then build output rows by indexing.

**However**: `ExtractorRegistry.extractValue` and `extractValueList` take
different code paths for multi-element vs single-element types. The batching
must preserve which path each field takes.

**New approach for `RowExtractor.run`**:

Before the row loop, pre-query each field across all rows:

```rescript
  // Pre-compute: for each field, collect matched elements for each row
  let preQueriedFields = resolvedFields->Array.map(((name, field, resolvedFieldType, nestedDefaults)) => {
    let isMulti = isMultiElementType(resolvedFieldType)
    // For each row, query this field's selector ONCE
    let perRowEls = limitedRows->Array.map(rowEl => {
      if isMulti {
        NodeHtmlParserBinding.querySelectorAll(rowEl, field.selector)
      } else {
        switch NodeHtmlParserBinding.querySelector(rowEl, field.selector)->Nullable.toOption {
        | Some(el) => [el]
        | None => []
        }
      }
    })
    (name, field, resolvedFieldType, nestedDefaults, perRowEls)
  })
```

Then the row-building loop indexes into `preQueriedFields[rowIdx]` instead
of re-querying:

```rescript
  let results: result<array<JSON.t>, schemaError> = {
    let outputRows: array<JSON.t> = []
    let rowCount = Array.length(limitedRows)
    let rowIdx = ref(0)
    let loopResult: ref<result<unit, schemaError>> = ref(Ok())
    while rowIdx.contents < rowCount {
      switch loopResult.contents {
      | Error(_) => rowIdx := rowCount  // break
      | Ok(_) => {
          let fieldResult = preQueriedFields->Array.reduce(
            (fAcc: result<array<(string, JSON.t)>, schemaError>,
             (name, field, resolvedFieldType, nestedDefaults, perRowEls)) => {
              switch fAcc {
              | Error(e) => Error(e)
              | Ok(pairs) => {
                  let rowEls = Array.get(perRowEls, rowIdx.contents)->Option.getOr([])
                  let value = if isMultiElementType(resolvedFieldType) {
                    ExtractorRegistry.extractValueList(
                      rowEls, resolvedFieldType, None,
                      schema.config.ignoreErrors, field.required, name, field.selector,
                    )
                  } else {
                    let maybeEl = Array.get(rowEls, 0)
                    ExtractorRegistry.extractValueOrAbsent(
                      maybeEl, resolvedFieldType, field.default, field.required,
                      name, field.selector, nestedDefaults, schema.config.ignoreErrors,
                    )
                  }
                  switch value {
                  | Error(e) => Error(e)
                  | Ok(v) => { pairs->Array.push((name, v)); Ok(pairs) }
                  }
                }
              }
            }, Ok([]))
          switch fieldResult {
          | Error(e) => loopResult := Error(e)
          | Ok(pairs) => outputRows->Array.push(JSON.Encode.object(Dict.fromArray(pairs)))
          }
          rowIdx := rowIdx.contents + 1
        }
      }
    }
    switch loopResult.contents {
    | Error(e) => Error(e)
    | Ok(_) => Ok(outputRows)
    }
  }
```

This changes the query count from R × M to R × M (pre-query phase) + R × M
(index lookups, which are O(1) array accesses). The CSS engine runs R × M
times total (same), but the query results are cached — no redundant CSS
evaluations if the same selector appears twice, and the row-building loop
is pure array indexing.

**The REAL optimization**: Pre-querying per FIELD (not per row) allows the
CSS engine to potentially batch internally. But even without node-html-parser
batching, the code is cleaner: separation of query phase from build phase.

**Verify**: `pnpm run res:build && pnpm run res:test` → all existing tests
pass (behavior must be identical).

### Step 2: Batch queries in TableFieldExtractor

Apply the same pattern to `src/schema/v2/extractors/TableFieldExtractor.res`.

Before the row loop (line 88), pre-query each column across all rows:

```rescript
  let rows = resolveRows(el, tableOpts.rowSelector)

  // Pre-compute: for each column, collect matched elements for each row
  let preQueriedCols = resolvedColumns->Array.map(((col, resolvedFieldType, nestedDefaults)) => {
    let isList = switch resolvedFieldType {
    | List(_) => true
    | _ => false
    }
    let perRowEls = rows->Array.map(rowEl => {
      if isList {
        NodeHtmlParserBinding.querySelectorAll(rowEl, col.selector)
      } else {
        switch rowEl->NodeHtmlParserBinding.querySelector(col.selector)->Nullable.toOption {
        | Some(el) => [el]
        | None => []
        }
      }
    })
    (col, resolvedFieldType, nestedDefaults, perRowEls)
  })
```

Then the row-building loop uses indexed access. The existing error-handling
logic (required field missing, ignoreErrors, default values) must be
preserved exactly.

**Verify**: `pnpm run res:build && pnpm run res:test` → all pass.

### Step 3: Add a scaling test

Add a test in `test/res/RowExtractor_test.res` that verifies performance
doesn't regress. Use a schema with many fields and many rows:

```rescript
test("RowExtractor handles 100 rows × 10 fields without timeout", () => {
  // Build HTML with 100 row elements, each with 10 fields
  // Run extraction
  // Assert result has 100 rows, each with 10 fields
  // (No explicit timing — just ensure it completes quickly)
})
```

This test guards against future N+1 regressions.

**Verify**: `pnpm run res:test` → all pass including the new scaling test.

## Test plan

- Existing `RowExtractor_test.res` tests must pass unchanged (behavior preserved)
- Existing `TableExtractor_test.res` tests must pass unchanged
- Add 1 scaling test (100×10) to guard against regressions

## Done criteria

- [ ] `pnpm run res:build` exits 0
- [ ] `pnpm run res:test` exits 0 — all existing tests pass
- [ ] `RowExtractor.run` pre-queries fields before the row loop
- [ ] `TableFieldExtractor.extract` pre-queries columns before the row loop
- [ ] No `querySelector(All)` calls inside the row-building loops
- [ ] At least 1 scaling test added
- [ ] No files outside the in-scope list are modified

## STOP conditions

- The `ExtractorRegistry.extractValue` / `extractValueOrAbsent` signatures
  don't match the pre-queried element array pattern — if so, keep the
  per-field query outside the row loop but still call the registry per row
  (the query is still batched; the extraction call is per-row).
- Existing tests fail after refactoring — indicates behavior change. The
  refactor MUST be behavior-preserving. If tests fail, the error-handling
  paths (required fields, ignoreErrors, defaults) may not be preserved
  correctly.
- `node-html-parser`'s `querySelectorAll` returns a different type than
  expected when called outside a row context — adjust the pre-query to
  use the same context (row element).

## Maintenance notes

- This is a pure refactoring with no behavior change. The test suite is the
  safety net — if all tests pass, the optimization is correct.
- The pre-query approach uses more memory (R × M element references held
  simultaneously). For very large datasets (100K+ rows), this trades CPU
  for memory. If memory becomes an issue, consider batching in chunks.
- The `ZipExtractor` already pre-queries correctly (it queries each field's
  selector against the document root once). This plan brings `RowExtractor`
  and `TableFieldExtractor` to the same pattern.
