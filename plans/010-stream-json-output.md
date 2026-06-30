# Plan 010: Stream JSON file output instead of buffering in memory

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 8e085f5..HEAD -- src/url/UrlRunner.res src/url/UrlOutputWriter.res`
> If changed, compare excerpts below against live code.

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: perf
- **Planned at**: commit `8e085f5`, 2026-06-30

## Why this matters

In URL mode with `--output file.json --format json`, all extracted rows are
buffered in a linked list in memory (up to 100K rows), then serialized and
written synchronously in one shot. At the 100K cap with 500B avg rows,
that's ~50MB heap plus the full serialization blocking the event loop.
Streaming eliminates the buffer, removes the 100K cap, and lets output start
flowing immediately.

## Current state

### `src/url/UrlRunner.res` (lines 57, 97-100, 169-183, 211-229)

The JSON file path works like this:
1. `jsonOutputRowCap = 100_000` (line 57)
2. `allResults = ref(list{})` — linked list accumulator (line 97)
3. `totalRowCount = ref(0)` — running count (line 98)
4. `jsonOutputHitCap = ref(false)` — cap flag (line 100)
5. Per fetch result: if JSON format + file output, append rows to `allResults`
   if under cap (lines 169-183)
6. After all fetches: `allResults->List.reverse->List.toArray->Array.flat`,
   then `writeFileSync(path, JSON.stringify(rows))` (lines 211-229)

### `src/url/UrlOutputWriter.res` (lines 63-77)

`writeFileJsonSync` does a synchronous `writeFileSync` of the entire array.

## Commands you will need

| Purpose   | Command                          | Expected on success |
|-----------|----------------------------------|---------------------|
| Build     | `pnpm run res:build`             | exit 0              |
| Tests     | `pnpm run res:test`              | all pass            |

## Scope

**In scope**:
- `src/url/UrlRunner.res` — replace buffered JSON output with streaming
- `src/url/UrlOutputWriter.res` — add streaming JSON write helpers

**Out of scope**:
- NDJSON output path (already streams correctly)
- Stdout output path (already streams correctly)
- Changes to `Fetcher.res` or `FetchStatsManager.res`

## Steps

### Step 1: Add streaming JSON write helpers to UrlOutputWriter

In `src/url/UrlOutputWriter.res`, add three new functions:

```rescript
/** Writes the opening bracket of a JSON array to a file synchronously.
    Called once before any rows are streamed. */
let beginJsonArraySync = (~writeFileSync: (string, string) => unit, ~path: string): unit =>
  writeFileSync(path, "[")

/** Appends a single JSON row as part of a streaming array.
    The caller tracks whether this is the first row (no comma prefix)
    or a subsequent row (comma prefix). */
let appendJsonRowAsync = (
  ~appendFile: (string, string) => promise<unit>,
  ~stringifyJson: JSON.t => string,
  ~path: string,
  ~isFirstRow: bool,
  ~json: JSON.t,
): promise<unit> = async (~appendFile, ~stringifyJson, ~path, ~isFirstRow, ~json) => {
  let rows = extractJsonArray(json)
  let content = rows->Array.map(stringifyJson)->Array.map(row =>
    if isFirstRow { row } else { "," ++ row }
  )->Array.join("")
  await appendFile(path, content)
}

/** Writes the closing bracket of a JSON array synchronously.
    Called once after all rows have been streamed. */
let endJsonArraySync = (~writeFileSync: (string, string) => unit, ~path: string): unit =>
  writeFileSync(path, "]")
```

**Note on `isFirstRow`**: The first batch of rows from the first successful
fetch should not have a leading comma. Subsequent batches need a comma
prefix. The caller (UrlRunner) tracks whether any rows have been written.

### Step 2: Replace buffered JSON output in UrlRunner

In `src/url/UrlRunner.res`, restructure the JSON file output path:

**2a.** Remove the buffered-accumulation state:
- Remove `allResults` (line 97)
- Remove `totalRowCount` (line 98)
- Remove `jsonOutputHitCap` (line 100)
- Remove `jsonOutputRowCap` (line 57)

**2b.** Add streaming state:
```rescript
    let jsonFileStarted = ref(false)  // Has the opening "[" been written?
```

**2c.** Change the JSON-file output case (lines 169-183) from:

```rescript
                    | (Some(_), Json) =>
                      if jsonOutputHitCap.contents {
                        ()
                      } else {
                        let batchRows = countRows(json)
                        if totalRowCount.contents + batchRows > jsonOutputRowCap {
                          ctx.io.err("Warning: JSON output exceeds 100,000 rows; capping...")
                          jsonOutputHitCap := true
                        } else {
                          totalRowCount := totalRowCount.contents + batchRows
                          let rows = urlOutputExtractJsonArray(json)
                          allResults := list{rows, ...allResults.contents}
                        }
                      }
```

To:
```rescript
                    | (Some(path), Json) => {
                        // Initialize the JSON file on first write
                        if !jsonFileStarted.contents {
                          UrlOutputWriter.beginJsonArraySync(
                            ~writeFileSync=ctx.deps.fs.writeFileSync,
                            ~path,
                          )
                          jsonFileStarted := true
                        }
                        // Stream this batch's rows
                        let promise = UrlOutputWriter.appendJsonRowAsync(
                          ~appendFile=ctx.deps.fs.appendFile,
                          ~stringifyJson=ctx.deps.serialize.stringifyJson,
                          ~path,
                          ~isFirstRow=totalRowCount.contents == 0,
                          ~json,
                        )
                        pendingWrites := list{promise, ...pendingWrites.contents}
                        let batchRows = countRows(json)
                        totalRowCount := totalRowCount.contents + batchRows
                      }
```

Keep `totalRowCount` (renamed to `rowsWritten`) to track whether commas are
needed.

**2d.** Change the final write (lines 211-229) from:

```rescript
    switch (options.output, options.outputFormat) {
    | (Some(path), Json) => {
        let flatResults = allResults.contents->List.reverse->List.toArray->Array.flat
        switch UrlOutputWriter.writeFileJsonSync(...) { ... }
      }
    | _ => ()
    }
```

To:
```rescript
    switch (options.output, options.outputFormat) {
    | (Some(path), Json) =>
      if jsonFileStarted.contents {
        // Close the JSON array
        UrlOutputWriter.endJsonArraySync(~writeFileSync=ctx.deps.fs.writeFileSync, ~path)
      } else {
        // No data was written — write an empty array
        UrlOutputWriter.beginJsonArraySync(~writeFileSync=ctx.deps.fs.writeFileSync, ~path)
        UrlOutputWriter.endJsonArraySync(~writeFileSync=ctx.deps.fs.writeFileSync, ~path)
      }
    | _ => ()
    }
```

**Verify**: `pnpm run res:build && pnpm run res:test` → all pass.

### Step 3: Update the report row count

The `FetchStatsManager.recordSuccess(mgr, ~rowCount)` calls already track
row counts per fetch. The report will still show correct totals. No change
needed.

### Step 4: Handle append errors

Since `appendJsonRowAsync` uses `appendFile` (async), errors should be
handled the same way as NDJSON appends — see Plan 004. If Plan 004 has
landed, use the same `result`-returning pattern. If not, wrap in try/catch
with a warning (same as `appendNdjsonToFile`).

**Verify**: `pnpm run res:test` → all pass.

## Test plan

- Existing `UrlRunner_test.res` tests (from Plan 008) should pass
- Add a test that verifies JSON file output is valid JSON:
  ```rescript
  test("Streaming JSON output produces valid JSON array", async () => {
    // Run with 3 successful fetches, --output /tmp/test.json --format json
    // Read the file and parse it
    // Assert it's a valid JSON array with correct row count
  })
  ```
- Add a test for empty result set (no successful fetches):
  ```rescript
  test("Streaming JSON output with zero results writes []", async () => {
    // All fetches fail, --output /tmp/empty.json --format json
    // Assert file content is "[]"
  })
  ```

## Done criteria

- [ ] `pnpm run res:build` exits 0
- [ ] `pnpm run res:test` exits 0
- [ ] No `jsonOutputRowCap` constant exists (removed)
- [ ] No `allResults` linked-list accumulator exists (removed)
- [ ] JSON file output streams rows incrementally (begin → appends → end)
- [ ] Output file contains valid JSON (`JSON.parse(content)` succeeds)
- [ ] Empty result set writes `[]`
- [ ] No files outside the in-scope list are modified

## STOP conditions

- `appendFile` interleaves with `writeFileSync` in a way that corrupts the
  JSON (e.g., async append happening after the sync `endJsonArraySync`).
  If so, make all operations sync (`writeFileSync` for appends too), or
  ensure `pendingWrites` are fully awaited before writing the closing `]`.
- The `beginJsonArraySync` truncates the file (overwrites with `[`) when
  it should append — verify the file doesn't exist before the first write,
  or use `truncate`/`open` semantics carefully.
- Existing E2E tests in `MainE2E_test.res` break — the output format must
  remain a valid JSON array. If the bracket placement is wrong, the JSON
  won't parse.

## Maintenance notes

- This plan removes the 100K row cap. Document this in `CHANGELOG.md` under
  `[Unreleased]` → `Fixed` or `Changed`.
- The streaming approach uses async `appendFile` for row data but sync
  `writeFileSync` for the opening `[` and closing `]`. This is intentional:
  the brackets are tiny and must be ordered correctly relative to the async
  appends. The `pendingWrites` await (already in UrlRunner) ensures all
  appends complete before the closing `]` is written.
- If Plan 004 (NDJSON error propagation) has landed, apply the same
  `result`-returning pattern to `appendJsonRowAsync` for consistency.
