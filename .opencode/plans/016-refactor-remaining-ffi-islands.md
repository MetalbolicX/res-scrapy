# Plan 016: Refactor remaining high-value FFI islands and document exceptions

> **Executor instructions**: Do this after Plans 013 and 014. Favor smaller,
> clearer boundaries over aggressive elimination. Some `%raw` is correct.
>
> **Drift check (run first)**:
> `git diff --stat 59685ea..HEAD -- src/schema/v2/parser/SchemaParser.res src/Main.res src/cli/Cli.res src/url/Fetcher.res src/bindings/NodeJsBinding.res`

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: `.opencode/plans/013-fix-json-parse-typing.md`, `.opencode/plans/014-replace-easy-raw-wrappers.md`
- **Category**: architecture
- **Planned at**: commit `59685ea`, 2026-06-30

## Why this matters

After the easy wins land, the remaining unsafe surface is concentrated in a few
larger islands. Those islands deserve a deliberate decision: either refactor
them into typed bindings where that improves clarity, or explicitly document why
they should stay raw. This plan prevents the repo from drifting back into ad-hoc
interop.

## Current state

- `src/schema/v2/parser/SchemaParser.res:14-25`
  ```rescript
  let toFieldsObject: 'a => {..} = %raw(`
    (rawFields) => {
      if (Array.isArray(rawFields)) {
        return Object.fromEntries(
          rawFields
            .filter(f => f && typeof f === 'object' && typeof f.name === 'string')
            .map(({ name, ...rest }) => [name, rest])
        );
      }
      return rawFields;
    }
  `)
  ```
- `src/Main.res:60-110` contains two raw blocks:
  - `isExecutedAsScript` uses `import.meta.url`
  - `registerGlobalRuntimeHandlers` uses `process.on(...)` plus a `globalThis`
    guard
- `src/cli/Cli.res:8-17`
  ```rescript
  let candidatePackagePaths: unit => array<string> = %raw(`() => {
    ... new URL('../package.json', import.meta.url) ...
  }`)
  ```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Build | `pnpm run res:build` | exit 0 |
| Tests | `pnpm run res:test` | all pass |

## Scope

**In scope**:

- `src/schema/v2/parser/SchemaParser.res`
- `src/Main.res`
- `src/cli/Cli.res`
- `src/bindings/NodeJsBinding.res`
- docs file if you add one for FFI conventions

**Out of scope**:

- changing runtime behavior of CLI startup
- removing `import.meta.url` raw usage if no clean equivalent exists
- `src/url/Fetcher.res` dynamic import refactor

## Steps

### Step 1: Decide whether `SchemaParser.toFieldsObject` earns a rewrite

Evaluate the current raw block against a typed rewrite. Only rewrite it if the
result is clearly simpler or safer. If the typed version becomes more verbose or
less readable, keep the raw block and add a short comment explaining why this is
an intentional interop island.

The output of this step is a decision in code, not a forced elimination.

**Verify**: `pnpm run res:build` -> exit 0

### Step 2: Extract typed bindings only where they buy clarity in `Main.res`

For `registerGlobalRuntimeHandlers`, typed bindings for `process.on` may improve
clarity if they reduce the size of the raw block without spreading complexity.

Do not touch `isExecutedAsScript` if the only blocker is `import.meta.url`. That
site is an acceptable exception.

**Verify**: `pnpm run res:build && pnpm run res:test` -> all pass

### Step 3: Leave `Cli.res` raw package-path discovery alone unless a cleaner
boundary emerges

The current `candidatePackagePaths` block also depends on `import.meta.url`.
Unless you can meaningfully reduce risk without adding abstraction, document it
as an accepted raw boundary and stop there.

**Verify**: `pnpm run res:build` -> exit 0

### Step 4: Document accepted FFI exceptions

Add one concise repo-local document or code comments that name the remaining
approved exceptions:

- `import.meta.url`
- dynamic `import()`
- any single explicit `JSON.t` -> `{..}` coercion boundary

The goal is policy clarity: future changes should add to that list deliberately,
not casually.

**Verify**: `pnpm run res:test` -> all pass

## Done criteria

- [ ] Remaining raw blocks in scope are either simplified or explicitly
  documented as intentional
- [ ] No attempt is made to “win” against `import.meta.url` with a worse
  abstraction
- [ ] `pnpm run res:build` exits 0
- [ ] `pnpm run res:test` exits 0

## STOP conditions

- Any proposed rewrite makes the code harder to read than the existing raw block.
- Removing a raw block requires a helper layer larger than the code being
  replaced.
- A verification command fails twice after a reasonable fix attempt.

## Maintenance notes

- This plan is where discipline matters. The right answer is not “remove every
  raw block”; it is “leave only the ones that are justified and obvious.”
