# Plan 015: Centralize test JSON coercion and trim E2E `Obj.magic`

> **Executor instructions**: Do this after Plan 013. Keep the behavior of the
> E2E tests intact; the goal is to remove repeated casts, not redesign tests.
>
> **Drift check (run first)**:
> `git diff --stat 59685ea..HEAD -- test/res/helpers/TestHelpers.res test/res/MainE2E_test.res test/res/ListExtractor_test.res`

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: `.opencode/plans/013-fix-json-parse-typing.md`
- **Category**: tests
- **Planned at**: commit `59685ea`, 2026-06-30

## Why this matters

The E2E suite currently stacks `Obj.magic` twice in common flows: once in test
helpers and again at the assertion site. That makes the suite noisy and hides
which coercions are legitimate. The right move is to centralize coercion in a
small number of helper functions so test call sites become explicit and boring.

## Current state

- `test/res/MainE2E_test.res` has repeated string-array casts:
  ```rescript
  let arr: array<string> = result.stdout->TestHelpers.arrayFromJsonString->Obj.magic
  ```
- The same file also has object-array casts:
  ```rescript
  let arr: array<{..}> = result.stdout->TestHelpers.arrayFromJsonString->Obj.magic
  ```
- And repeated empty-object fallbacks:
  ```rescript
  let firstRow: {..} = arr->Array.get(0)->Option.getOr(Obj.magic(%raw("({})")))
  ```
- `test/res/helpers/TestHelpers.res` currently exposes only broad helpers like
  `arrayFromJsonString` and `objectFromJsonString`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Build | `pnpm run res:build` | exit 0 |
| Tests | `pnpm run res:test` | all pass |

## Scope

**In scope**:

- `test/res/helpers/TestHelpers.res`
- `test/res/MainE2E_test.res`
- `test/res/ListExtractor_test.res` if helper naming cleanup reaches it

**Out of scope**:

- production modules
- broad restructuring of the E2E suite
- replacing open-object assertions with fully typed records

## Steps

### Step 1: Add typed helper entry points

In `TestHelpers`, add narrow helpers for the shapes the tests actually consume,
for example:

- `stringArrayFromJsonString`
- `objectArrayFromJsonString`
- optional `emptyObject` helper for `{..}` fallbacks

Keep the existing generic helpers only if other tests still need them.

**Verify**: `pnpm run res:build` -> exit 0

### Step 2: Replace repeated E2E casts with helper calls

Update `test/res/MainE2E_test.res` so call sites use the narrow helpers instead
of `->Obj.magic` chains.

The resulting test code should make the expected JSON shape obvious at the call
site.

**Verify**: `pnpm run res:test` -> all pass

### Step 3: Remove duplicate empty-object fallback patterns

Replace repeated `Obj.magic(%raw("({})"))` fallback expressions with one named
helper or constant in `TestHelpers` if the pattern remains necessary.

Do not spread new `%raw` across test files.

**Verify**: `pnpm run res:build && pnpm run res:test` -> all pass

## Done criteria

- [ ] `test/res/MainE2E_test.res` no longer chains `->Obj.magic` after
  `TestHelpers.arrayFromJsonString`
- [ ] repeated empty-object fallbacks are centralized
- [ ] helper names make the expected shape explicit
- [ ] `pnpm run res:build` exits 0
- [ ] `pnpm run res:test` exits 0

## STOP conditions

- The cleanup requires invasive rewriting of assertions unrelated to JSON shape.
- A helper name cannot stay honest without introducing behavior not already in
  the tests.
- A verification command fails twice after a reasonable fix attempt.

## Maintenance notes

- This plan intentionally stops short of full typed decoders for tests. That is
  overkill for CLI output smoke tests unless the output schema becomes unstable.
