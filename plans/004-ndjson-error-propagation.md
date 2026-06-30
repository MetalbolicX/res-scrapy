# Plan 004: Propagate NDJSON file-write errors to exit code

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 8e085f5..HEAD -- src/url/UrlOutputWriter.res src/url/UrlRunner.res src/url/FetchStatsManager.res`
> If any in-scope file changed, compare excerpts below against live code.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: MED
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `8e085f5`, 2026-06-30

## Why this matters

In URL mode with `--output file.json --format ndjson`, if `appendFile` fails
(disk full, permission denied), the error is swallowed: a warning goes to
stderr but the tool exits 0. Users get an empty or partial file with no error
signal. This plan makes file-write failures affect the exit code so pipeline
automation can detect data loss.

## Current state

### `src/url/UrlOutputWriter.res:43-58`

```rescript
let appendNdjsonToFile: (
  ~appendFile: (string, string) => promise<unit>,
  ~err: string => unit,
  ~stringifyJson: JSON.t => string,
  ~path: string,
  ~json: JSON.t,
) => promise<unit> = async (~appendFile, ~err, ~stringifyJson, ~path, ~json) => {
  let rows = extractJsonArray(json)
  let content = rows->Array.map(stringifyJson)->Array.join("\n") ++ "\n"
  try {
    await appendFile(path, content)
  } catch {
  | exn =>
    err(`Warning: Failed to append to output file "${path}": ${ExnUtils.message(exn)}`)
  }
}
```

The function always resolves `unit`, even on failure. The caller cannot tell
success from failure.

### `src/url/UrlRunner.res:159-167` (caller)

```rescript
                    | (Some(path), Ndjson) => {
                        let promise = UrlOutputWriter.appendNdjsonToFile(
                          ~appendFile=ctx.deps.fs.appendFile,
                          ~err=ctx.io.err,
                          ~stringifyJson=ctx.deps.serialize.stringifyJson,
                          ~path,
                          ~json,
                        )
                        pendingWrites := list{promise, ...pendingWrites.contents}
                      }
```

The promise is stashed in `pendingWrites` and awaited at line 200-203, but
the result (always `unit`) is never checked. No error propagates to the
exit-code logic.

### `src/url/FetchStatsManager.res:45-46` (exit code logic)

```rescript
let shouldExitWithError = (mgr: t): bool =>
  mgr.stats.succeeded == 0 && mgr.stats.failed > 0
```

Exit code 1 only fires if all URLs failed. File-write failures have no effect.

## Commands you will need

| Purpose   | Command                          | Expected on success |
|-----------|----------------------------------|---------------------|
| Build     | `pnpm run res:build`             | exit 0              |
| Tests     | `pnpm run res:test`              | all pass            |

## Scope

**In scope**:
- `src/url/UrlOutputWriter.res` — return `result<unit, string>` from `appendNdjsonToFile`
- `src/url/UrlRunner.res` — track write failures, influence exit code
- `src/url/FetchStatsManager.res` — add write-failure tracking (optional, see step 2)

**Out of scope**:
- Changes to stdout NDJSON path (it works correctly)
- Changes to JSON file output path (uses sync `writeFileSync`, already returns `result`)
- Changes to `Reporter.res` (stats formatting)

## Steps

### Step 1: Change `appendNdjsonToFile` return type

In `src/url/UrlOutputWriter.res`, change the return type from `promise<unit>`
to `promise<result<unit, string>>` and propagate the error instead of
swallowing it.

Current (lines 43-58):
```rescript
) => promise<unit> = async (~appendFile, ~err, ~stringifyJson, ~path, ~json) => {
  let rows = extractJsonArray(json)
  let content = rows->Array.map(stringifyJson)->Array.join("\n") ++ "\n"
  try {
    await appendFile(path, content)
  } catch {
  | exn =>
    err(`Warning: Failed to append to output file "${path}": ${ExnUtils.message(exn)}`)
  }
}
```

New:
```rescript
) => promise<result<unit, string>> = async (~appendFile, ~err, ~stringifyJson, ~path, ~json) => {
  let rows = extractJsonArray(json)
  let content = rows->Array.map(stringifyJson)->Array.join("\n") ++ "\n"
  try {
    await appendFile(path, content)
    Ok(())
  } catch {
  | exn =>
    let msg = `Failed to append to output file "${path}": ${ExnUtils.message(exn)}`
    err(`Warning: ${msg}`)
    Error(msg)
  }
}
```

Keep the `err` warning so users still see the failure on stderr. The
`result` return lets the caller track it.

**Verify**: `pnpm run res:build` → exit 0. The type change will surface
type errors in `UrlRunner.res` — fix them in step 2.

### Step 2: Track write failures in UrlRunner

In `src/url/UrlRunner.res`, update the NDJSON-append path and the
`pendingWrites` type.

**2a.** Change the `pendingWrites` type (line 99):
Current:
```rescript
    let pendingWrites: ref<list<promise<unit>>> = ref(list{})
```
New:
```rescript
    let pendingWrites: ref<list<promise<result<unit, string>>>> = ref(list{})
```

**2b.** After awaiting `pendingWrites` (lines 200-203), check for errors:

Current:
```rescript
    let writes = pendingWrites.contents->List.reverse->List.toArray
    if Array.length(writes) > 0 {
      let _ = await Promise.all(writes)
    }
```

New:
```rescript
    let writes = pendingWrites.contents->List.reverse->List.toArray
    let writeFailures = ref(0)
    if Array.length(writes) > 0 {
      let results = await Promise.all(writes)
      results->Array.forEach(result =>
        switch result {
        | Ok(_) => ()
        | Error(_) => writeFailures := writeFailures.contents + 1
        }
      )
    }
```

**2c.** After the report is printed (after line 232), add a check for
write failures:

```rescript
    // Exit code: 0 if all succeeded AND no write failures
    if FetchStatsManager.shouldExitWithError(mgr) || writeFailures.contents > 0 {
      if writeFailures.contents > 0 {
        ctx.io.err(`Warning: ${Int.toString(writeFailures.contents)} output write(s) failed`)
      }
      ctx.io.exit(1)
    }
```

Replace the existing exit-code block (lines 234-237).

**Verify**: `pnpm run res:build && pnpm run res:test` → all pass. If type
errors remain in `UrlRunner.res`, the `Promise.all` return type may need
explicit annotation — ReScript infers `array<result<unit, string>>`.

### Step 3: Add a test for write-failure exit code

Create or update `test/res/UrlRunner_test.res` (if it doesn't exist, model
after `test/res/ReporterPipeline_test.res`). Inject a fake `appendFile`
that always rejects:

```rescript
test("UrlRunner exits non-zero when NDJSON file write fails", () => {
  let ctx = AppContext.{
    // ... production deps, but override fs.appendFile to reject
    deps: {
      ...production.deps,
      fs: {
        ...production.deps.fs,
        appendFile: (_, _) => Promise.reject(Js.Exn.raise("EACCES")),
      },
    },
    io: {
      out: _ => (),
      err: msg => /* capture error */,
      warn: _ => (),
      exit: code => /* assert code == 1 */,
    },
  }
  // Run with a single URL, mock fetch returning valid HTML, --output /tmp/test.ndjson --format ndjson
  // Assert exit was called with 1
})
```

If full integration testing of UrlRunner is too complex (it requires mocking
fetch), at minimum add a unit test in `test/res/UrlOutputWriter_test.res`
that verifies `appendNdjsonToFile` returns `Error(...)` when `appendFile`
rejects.

**Verify**: `pnpm run res:test` → new test passes.

## Test plan

- `test/res/UrlOutputWriter_test.res`: assert `appendNdjsonToFile` returns
  `Error(msg)` when `appendFile` throws. Assert it returns `Ok(())` on success.
- Optionally: integration test in `UrlRunner_test.res` (if feasible with
  the DI pattern) that verifies exit code 1 on write failure.

## Done criteria

- [ ] `pnpm run res:build` exits 0
- [ ] `pnpm run res:test` exits 0
- [ ] `appendNdjsonToFile` returns `result<unit, string>` (not `unit`)
- [ ] `UrlRunner` tracks write failures and exits 1 when any occur
- [ ] At least one new test covers the write-failure path
- [ ] No files outside the in-scope list are modified

## STOP conditions

- The `Promise.all` return type in ReScript doesn't give `array<result<...>>`
  directly — if the type inference fails, use `Promise.allSettled` or
  iterate with `for` + `await` instead.
- Full integration testing of `UrlRunner` proves too complex for a unit
  test — in that case, write only the `UrlOutputWriter` unit test and note
  the integration gap.

## Maintenance notes

- This change makes NDJSON file output stricter: previously, a write failure
  was a warning; now it's an error exit. Document this in `CHANGELOG.md`
  under `[Unreleased]` → `Changed`.
- The JSON file path (`writeFileSync`) already propagates errors via `result`
  — this plan brings NDJSON to parity.
