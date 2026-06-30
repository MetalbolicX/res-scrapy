# Plan 005: Deduplicate output helpers and exit-with-error boilerplate

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 8e085f5..HEAD -- src/core/OutputWriter.res src/Main.res src/table/TableRunner.res src/schema/SchemaRunner.res src/extraction/SelectorExtractor.res`
> If any in-scope file changed, compare excerpts below against live code.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `8e085f5`, 2026-06-30

## Why this matters

Two patterns of duplication add maintenance tax: (1) `OutputWriter.res` has
sync and async versions of identical write logic, and (2) every runner module
repeats the same `err → exit(1)` error-handling incantation. Consolidating
these eliminates ~30 lines of duplicate code and makes adding new extraction
modes zero-boilerplate.

## Current state

### Duplication A: OutputWriter sync/async paths

`src/core/OutputWriter.res` has 4 functions that pair sync/async:
- `writeText` (lines 47-65) — sync, uses `writeFile: (string, string) => unit`
- `writeTextAsync` (lines 79-95) — async, uses `writeFile: (string, string) => promise<unit>`
- `write` (lines 67-77) — wraps `writeText` with format routing
- `writeAsync` (lines 97-107) — wraps `writeTextAsync` with format routing

The sync and async paths are structurally identical except for the `writeFile`
signature. The shared `computeOutputText` helper (lines 26-45) already
centralizes format routing.

### Duplication B: Runner exit-with-error boilerplate

`src/Main.res:1-4`:
```rescript
let exitWithError = (ctx: AppContext.appContext, err: AppError.appError) => {
  ctx.io.err(AppError.toMessage(err))
  ctx.io.exit(1)
}
```

This helper exists in `Main.res` but is NOT exported or shared. Each runner
duplicates the pattern:

`src/schema/SchemaRunner.res:39-42`:
```rescript
  | Error(err) => {
      ctx.io.err(AppError.toMessage(err))
      ctx.io.exit(1)
    }
```

`src/extraction/SelectorExtractor.res:45-48`:
```rescript
  | Error(msg) => {
      ctx.io.err(AppError.toMessage(AppError.ExtractionError(msg)))
      ctx.io.exit(1)
    }
```

`src/table/TableRunner.res` — same pattern.

## Commands you will need

| Purpose   | Command                          | Expected on success |
|-----------|----------------------------------|---------------------|
| Build     | `pnpm run res:build`             | exit 0              |
| Tests     | `pnpm run res:test`              | all pass            |

## Scope

**In scope**:
- `src/core/OutputWriter.res` — consolidate sync/async write paths
- `src/Main.res` — export `exitWithError` or move to a shared location
- `src/table/TableRunner.res` — use shared `exitWithError`
- `src/schema/SchemaRunner.res` — use shared `exitWithError`
- `src/extraction/SelectorExtractor.res` — use shared `exitWithError`

**Out of scope**:
- Changes to `UrlRunner.res` (it has a different error pattern for stats)
- Changes to the `AppContext` type signature (no new deps needed)
- Changes to `UrlOutputWriter.res`

## Steps

### Step 1: Consolidate OutputWriter to async-only

The stdin-mode callers (via `OutputWriter.writeOutput`) currently use sync
`writeFileSync`. The async path is used by URL mode. Since ReScript can
`await` in any `async` function, and the stdin path can be made async too,
consolidate to a single async implementation.

**1a.** In `src/core/OutputWriter.res`, replace `writeText` + `writeTextAsync`
with a single async function:

Current `writeText` (sync):
```rescript
let writeText = (
  ~target: outputTarget,
  ~text: string,
  ~writeFile: (string, string) => unit,
  ~out: string => unit,
): result<unit, AppError.appError> =>
```

Current `writeTextAsync`:
```rescript
let writeTextAsync = (
  ~target: outputTarget,
  ~text: string,
  ~writeFile: (string, string) => promise<unit>,
  ~out: string => unit,
): promise<result<unit, AppError.appError>> =>
```

**IMPORTANT**: `writeOutput` (line 115) uses `ctx.deps.fs.writeFileSync` and
is called from `SchemaRunner.runSchemaMode` and `SelectorExtractor.runSelectorMode`
which are NOT async functions. Making `writeOutput` async requires changing
those callers to async too.

**Safer approach**: Keep both functions but make `writeText` a thin wrapper
that wraps the sync `writeFile` into a promise-compatible shape, or keep the
sync/async split but extract the shared logic.

**ACTUALLY**: The safest, lowest-risk approach is to keep both paths but
extract the duplicated `computeOutputText` call (already done — it's shared).
The duplication is only in the I/O wrapper. Since the I/O signatures are
genuinely different (`unit` vs `promise<unit>`), ReScript's type system
requires separate functions.

**Decision**: SKIP the OutputWriter consolidation for this plan. The sync/async
split is forced by the type system. Focus only on the exit-with-error helper
(Duplication B).

### Step 2: Create a shared `exitWithError` helper

**2a.** In `src/core/AppContext.res` (or a new `src/core/ExitHelper.res`),
add a helper function:

If adding to `AppContext.res`:
```rescript
let exitWithError = (ctx: appContext, err: AppError.appError) => {
  ctx.io.err(AppError.toMessage(err))
  ctx.io.exit(1)
}

let exitWithErrorMsg = (ctx: appContext, msg: string) => {
  ctx.io.err(msg)
  ctx.io.exit(1)
}
```

Add these to the `.resi` interface file too.

**2b.** In `src/Main.res`, remove the local `exitWithError` (lines 1-4) and
use `AppContext.exitWithError` instead. Update all call sites in `Main.res`.

**2c.** In `src/schema/SchemaRunner.res`, replace inline error handling:

Current (lines 39-42):
```rescript
  | Error(err) => {
      ctx.io.err(AppError.toMessage(err))
      ctx.io.exit(1)
    }
```
New:
```rescript
  | Error(err) => AppContext.exitWithError(ctx, err)
```

Do the same for lines 46-49.

**2d.** In `src/extraction/SelectorExtractor.res`, replace (lines 45-48):
```rescript
  | Error(msg) => {
      ctx.io.err(AppError.toMessage(AppError.ExtractionError(msg)))
      ctx.io.exit(1)
    }
```
New:
```rescript
  | Error(msg) => AppContext.exitWithError(ctx, AppError.ExtractionError(msg))
```

**2e.** In `src/table/TableRunner.res`, apply the same pattern.

**Verify**: `pnpm run res:build && pnpm run res:test` → all pass.

### Step 3: Verify no inline `ctx.io.err(...) → ctx.io.exit(1)` remains

Search for the pattern:
```bash
rg "ctx\.io\.err.*ctx\.io\.exit" src/ --include="*.res"
```

The only remaining instances should be in `UrlRunner.res` (which has a
different error pattern involving stats) and in `Main.res`'s
`registerGlobalRuntimeHandlers` (which uses `Console.error` directly for
process-level handlers, not `ctx.io.err`).

**Verify**: `rg "ctx\.io\.err" src/schema/SchemaRunner.res src/extraction/SelectorExtractor.res src/table/TableRunner.res`
→ no matches (they now use `AppContext.exitWithError`).

## Test plan

- No new tests needed — this is a pure refactor.
- Existing tests should pass unchanged (behavior is identical).
- Run `pnpm run res:test` to confirm.

## Done criteria

- [ ] `pnpm run res:build` exits 0
- [ ] `pnpm run res:test` exits 0
- [ ] `AppContext.exitWithError` exists and is exported in `.resi`
- [ ] `Main.res`, `SchemaRunner.res`, `SelectorExtractor.res`,
      `TableRunner.res` use the shared helper
- [ ] `rg "ctx\.io\.err.*ctx\.io\.exit" src/schema/ src/extraction/ src/table/`
      returns no matches
- [ ] No files outside the in-scope list are modified

## STOP conditions

- Making `AppContext.exitWithError` requires changing the `appContext` type
  (it shouldn't — `exitWithError` takes `ctx` as a parameter, not as a
  record field). If the type needs changing, STOP.
- Any existing test fails after the refactor (indicates behavior change —
  the refactor must be behavior-preserving).

## Maintenance notes

- The `OutputWriter` sync/async split was kept because ReScript's type system
  requires separate functions for `(string, string) => unit` vs
  `(string, string) => promise<unit>`. A future cleanup could make
  `writeFileSync` async too, but that ripples through `Main.res` and is not
  worth the risk for this plan.
