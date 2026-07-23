# Plan 013: Establish baselines for the follow-up refactors

> **Executor instructions**: Run the verification steps first and record the current behavior before changing anything later in the chain. If the code at the cited locations has drifted, stop and report.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tests
- **SDD**: No
- **Planned at**: commit `df9000c`, 2026-07-23

## Why this matters

These later plans change behavior-adjacent code paths. A baseline lets us prove the refactors preserve URL output, error reporting, and extraction semantics.

## Current state

- `src/url/UrlRunner.res` — current URL success/failure flow and output routing.
- `src/core/OutputWriter.res`, `src/url/UrlOutputWriter.res` — current output error messages and error types.
- `src/schema/v2/executor/{RowExtractor,ZipExtractor}.res` and `src/schema/v2/utils/date/parseDate.mts` — current hot paths for extraction and date parsing.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Baseline verification | `pnpm run release:check` | exit 0 |
| Focused tests | `pnpm run res:test` | all pass |

## Scope

**In scope**
- `test/res/UrlRunner_test.res`
- `test/res/OutputPipeline_test.res`
- `test/res/{RowExtractor,ZipExtractor,DateUtils}_test.res`

## Steps

### Step 1: Capture current URL behavior

- Record the existing success path, output routing, and failure handling in `UrlRunner_test.res`.

**Verify**: `pnpm run res:test` → all URL tests pass.

### Step 2: Capture output and extraction baselines

- Run the output pipeline and extraction tests that cover writer errors, row extraction, and date parsing.

**Verify**: `pnpm run res:test` → all targeted suites pass.

### Step 3: Run the repo-wide guard

- Execute the release check and note the result before touching the later phases.

**Verify**: `pnpm run release:check` → exit 0.

## Test plan

- Keep the existing regression suites green.
- Record the baseline outputs or timings only if they are already part of the test harness.

## Done criteria

- [ ] `pnpm run res:test` passes
- [ ] `pnpm run release:check` passes
- [ ] No production files changed

## STOP conditions

- The current test names or flows do not match the files above.
- `release:check` fails before any later plan starts.
