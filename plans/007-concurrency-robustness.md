# Plan 007: Harden concurrency — semaphore leak + allSettled

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 8e085f5..HEAD -- src/url/Fetcher.res`
> If changed, compare excerpts below against live code.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `8e085f5`, 2026-06-30

## Why this matters

Two concurrency bugs in `Fetcher.res` can cause deadlocks or abandoned work
under failure conditions. The semaphore can permanently consume all slots if
a fetch promise rejects unexpectedly (no `try/finally`), and `Promise.all`
aborts all in-flight work on the first rejection. Both are one-block fixes.

## Current state

### Bug A: Semaphore slot leak (lines 249-254)

```rescript
  let fetchWithSemaphore = async url => {
    await acquire(sem)
    await acquireStartSlot(limiter)
    let result = await fetchWithRetry(url, options.userAgent, options.timeoutSeconds, options.retryCount, options.headers)
    release(sem)
    {url, result}
  }
```

If `fetchWithRetry` (or `acquireStartSlot`) throws an unexpected exception
(not caught by the `try/catch` inside `fetchOnce`), the `release(sem)` line
is never reached. The semaphore slot is permanently consumed. With N
concurrent failures, all N slots fill up and remaining tasks deadlock on
`acquire`.

### Bug B: `Promise.all` fail-fast (lines 257-259)

```rescript
  let promises = urls->Array.map(fetchWithSemaphore)
  let results = await Promise.all(promises)
  results
```

`Promise.all` rejects immediately when any promise rejects, without waiting
for the others. In-flight fetches continue running uselessly. The function
returns only the first error — all other results (successes and failures)
are lost.

## Commands you will need

| Purpose   | Command                          | Expected on success |
|-----------|----------------------------------|---------------------|
| Build     | `pnpm run res:build`             | exit 0              |
| Tests     | `pnpm run res:test`              | all pass            |

## Scope

**In scope**:
- `src/url/Fetcher.res` — add try/finally to `fetchWithSemaphore`, switch to `Promise.allSettled`

**Out of scope**:
- Changes to `UrlRunner.res` (the consumer of `fetchAll`)
- Changes to `FetchStatsManager.res`
- Changes to the retry/backoff logic

## Steps

### Step 1: Add try/finally to `fetchWithSemaphore`

In `src/url/Fetcher.res`, change lines 249-254.

Current:
```rescript
  let fetchWithSemaphore = async url => {
    await acquire(sem)
    await acquireStartSlot(limiter)
    let result = await fetchWithRetry(url, options.userAgent, options.timeoutSeconds, options.retryCount, options.headers)
    release(sem)
    {url, result}
  }
```

New:
```rescript
  let fetchWithSemaphore = async url => {
    await acquire(sem)
    try {
      await acquireStartSlot(limiter)
      let result = await fetchWithRetry(url, options.userAgent, options.timeoutSeconds, options.retryCount, options.headers)
      {url, result}
    } finally {
      release(sem)
    }
  }
```

The `try/finally` ensures `release(sem)` runs even if `fetchWithRetry` or
`acquireStartSlot` throws. The result `{url, result}` is returned from the
`try` block.

**Note**: ReScript supports `try ... finally`. Check by running
`pnpm run res:build` after the edit.

**Verify**: `pnpm run res:build` → exit 0.

### Step 2: Switch `Promise.all` to `Promise.allSettled`

In `src/url/Fetcher.res`, change lines 257-259.

Current:
```rescript
  let promises = urls->Array.map(fetchWithSemaphore)
  let results = await Promise.all(promises)
  results
```

`fetchWithSemaphore` returns `fetchResult` (which has `result: result<string, fetchError>`).
It never rejects — the error is captured inside the `result` field. So
`Promise.all` is safe in the normal case. However, if a truly unexpected
exception escapes the `try/finally` (e.g., a stack overflow, OOM), `allSettled`
provides additional safety.

New:
```rescript
  let promises = urls->Array.map(fetchWithSemaphore)
  let settled = await Promise.allSettled(promises)
  settled->Array.map(outcome =>
    switch outcome {
    | Promise.Fulfilled(result) => result
    | Promise.Rejected(exn) =>
      {
        url: "",  // URL is unknown here; the rejection lost it
        result: Error(NetworkError(`Unexpected rejection: ${ExnUtils.message(exn)}`)),
      }
    }
  )
```

**IMPORTANT**: Check whether ReScript's `Promise` module exposes `allSettled`
and the `Fulfilled`/`Rejected` variants. If not available in the
`@rescript/runtime` version used, use this alternative pattern:

```rescript
  let promises = urls->Array.map(url =>
    fetchWithSemaphore(url)->Promise.catch(exn =>
      Promise.resolve({
        url,
        result: Error(NetworkError(`Unexpected rejection: ${ExnUtils.message(exn)}`)),
      })
    )
  )
  await Promise.all(promises)
```

This `Promise.catch` fallback wraps each promise individually, converting
rejections into fulfilled values. This preserves the `url` in the error case.

**Verify**: `pnpm run res:build && pnpm run res:test` → all pass.

### Step 3: Add tests for semaphore release on failure

Update `test/res/Fetcher_test.res` (if it exists). Add a test that verifies
the semaphore releases even when a fetch fails:

```rescript
test("Semaphore releases on fetch failure", async () => {
  // Create a semaphore with capacity 1
  // Start two fetches where the first fails immediately
  // Assert the second fetch acquires (doesn't deadlock)
})
```

If testing the semaphore directly is too complex, add a test that verifies
`fetchAll` returns results for ALL URLs even when some fail (not just the
first error):

```rescript
test("fetchAll returns all results even when some URLs fail", async () => {
  // Fetch 3 URLs where one returns HTTP 500
  // Assert the result array has 3 entries, not just the error
})
```

**Verify**: `pnpm run res:test` → new test passes.

## Test plan

- Semaphore release on failure: verify all tasks complete (no deadlock)
- `fetchAll` returns all results: verify partial failures don't lose
  successful results
- Existing `Fetcher_test.res` tests should pass unchanged

## Done criteria

- [ ] `pnpm run res:build` exits 0
- [ ] `pnpm run res:test` exits 0
- [ ] `fetchWithSemaphore` uses `try/finally` to guarantee `release(sem)`
- [ ] `fetchAll` returns results for ALL URLs (not fail-fast)
- [ ] At least one new test verifies the semaphore-release-on-failure path
- [ ] No files outside `Fetcher.res` and its test are modified

## STOP conditions

- ReScript v12 doesn't support `try/finally` syntax (unlikely — it does).
  If the build fails on `finally`, use a manual `release` in both branches.
- `Promise.allSettled` is not available in the ReScript runtime — use the
  `Promise.catch` alternative described in Step 2.
- The existing `Fetcher_test.res` mocks don't support the failure scenarios
  needed for the new test — simplify to a unit test of `release` after
  an exception.

## Maintenance notes

- The `Promise.catch` approach (alternative in Step 2) preserves the `url`
  in error results, which `allSettled` does not (the rejection loses
  closure context). Prefer `Promise.catch` if `url` is needed in error
  reporting.
- The `try/finally` is the critical fix — `allSettled` is defense-in-depth.
  If pressed for time, prioritize Step 1.
