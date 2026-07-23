# Plan 015: Simplify Fetcher and Reporter internals

> **Executor instructions**: Keep this phase inside the URL subsystem. Refactor internals, not behavior.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: plans/013-baseline-verification.md
- **Category**: tech-debt
- **SDD**: No
- **Planned at**: commit `df9000c`, 2026-07-23

## Why this matters

This phase removes wrapper-only indirection and pulls reusable concurrency primitives out of Fetcher so the module owns orchestration, not generic machinery.

## Current state

- `src/url/Fetcher.res` — contains fetch orchestration plus semaphore and start-limiter helpers.
- `src/url/FetchStatsManager.res`, `src/url/Reporter.res` — stats wrapper vs reporter logic split.
- `src/url/Fetcher.res`, `src/url/UrlRunner.res`, `src/core/AppContext.res` — positional config flow into fetch calls.

## Steps

### Step 1: Extract concurrency helpers

- Move semaphore code into `src/core/Semaphore.res` and start-delay code into `src/core/StartLimiter.res`.

**Verify**: Fetcher tests still pass and the helper code is no longer in `Fetcher.res`.

### Step 2: Merge FetchStatsManager into Reporter

- Move the thin delegation logic into `Reporter.res` and delete `FetchStatsManager.res`.

**Verify**: reporter and pipeline tests still pass; no caller imports the removed module.

### Step 3: Replace positional fetch args with a record

- Introduce a record for single-fetch settings and update the internal call sites in `Fetcher.res` and `UrlRunner.res`.

**Verify**: fetch tests pass and the new call sites are clearer than the positional version.

### Step 4: Tighten the test net

- Add or update focused tests for concurrency limits, stats reporting, and fetch configuration.

**Verify**: `pnpm run res:test` passes for Fetcher/Reporter suites.

## Deliverables

- [ ] Fetcher no longer owns generic concurrency primitives
- [ ] FetchStatsManager removed or reduced to zero-logic glue
- [ ] Fetch configuration becomes a record
- [ ] Fetch and reporter tests remain green

## STOP conditions

- Any refactor starts changing output formats or error contracts.
- The move from wrapper to reporter requires touching unrelated URL-mode logic.
