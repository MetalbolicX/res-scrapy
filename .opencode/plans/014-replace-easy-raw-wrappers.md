# Plan 014: Replace easy `%raw` wrappers with typed bindings

> **Executor instructions**: Follow the steps in order. Verify after each one.
> If a STOP condition occurs, stop and report.
>
> **Drift check (run first)**:
> `git diff --stat 59685ea..HEAD -- src/stdio/StdIn.res src/core/ExnUtils.res src/core/OutputWriter.res src/schema/v2/parser/SchemaParser.res src/schema/v2/extractors/JsonExtractor.res`

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `59685ea`, 2026-06-30

## Why this matters

Not all `%raw` is bad. Some of it is the correct interop tool. But several sites
in this repo are tiny wrappers around APIs ReScript can already express with a
typed `external` or stdlib function. Replacing those low-risk wrappers shrinks
the untyped surface without changing architecture.

## Current state

- `src/stdio/StdIn.res:10-11`
  ```rescript
  let startTimeout: (int, unit => unit) => timeoutId = %raw(`(ms, cb) => setTimeout(cb, ms)`)
  let clearTimeout_: timeoutId => unit = %raw(`id => clearTimeout(id)`)
  ```
- `src/core/ExnUtils.res:25-29`
  ```rescript
  let stack: JsExn.t => option<string> = jsExn =>
    switch %raw(`({stack}) => (typeof stack === "string" ? stack : null)`)(jsExn) {
    | Some(s) => Some(s)
    | None => None
    }
  ```
- `src/core/OutputWriter.res:5-15`
  ```rescript
  let jsonArrayToNdjson: string => option<string> = %raw(`raw => {
    try {
      const value = JSON.parse(raw);
      if (!Array.isArray(value)) {
        return undefined;
      }
      return value.map(item => JSON.stringify(item)).join("\n");
    } catch {
      return undefined;
    }
  }`)
  ```
- `src/schema/v2/parser/SchemaParser.res:29`
  ```rescript
  let keys: array<string> = %raw(`(obj) => Object.keys(obj)`)(fieldsObj)
  ```
- `src/schema/v2/extractors/JsonExtractor.res:50`
  ```rescript
  if v == %raw("null") || v == %raw("undefined") {
  ```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Build | `pnpm run res:build` | exit 0 |
| Tests | `pnpm run res:test` | all pass |

## Scope

**In scope**:

- `src/stdio/StdIn.res`
- `src/core/ExnUtils.res`
- `src/core/OutputWriter.res`
- `src/schema/v2/parser/SchemaParser.res`
- `src/schema/v2/extractors/JsonExtractor.res`
- `src/bindings/NodeJsBinding.res` only if you need to add a shared binding such
  as `Object.keys`

**Out of scope**:

- `import.meta.url` raw blocks
- `dynamic import()` raw blocks
- broad parser restructuring

## Steps

### Step 1: Replace timeout wrappers with typed bindings

Refactor `src/stdio/StdIn.res` to use typed bindings instead of `%raw` for
`setTimeout` and `clearTimeout`.

Prefer either stdlib globals or local `external` declarations that preserve the
existing `timeoutId` opacity.

**Verify**: `pnpm run res:build` -> exit 0

### Step 2: Replace raw exception stack extraction

In `src/core/ExnUtils.res`, replace the inline raw destructuring block with a
typed accessor. A local `@get` external for the `stack` property is enough if
the stdlib does not already expose the shape you need.

Preserve current behavior: only return `Some(stack)` when the property is a
string.

**Verify**: `pnpm run res:test` -> all pass

### Step 3: Rewrite `jsonArrayToNdjson` in ReScript

Replace the raw implementation in `src/core/OutputWriter.res` with ordinary
ReScript using existing JSON helpers:

- parse with `NodeJsBinding.jsonParse`
- reject non-array values
- stringify each item with `NodeJsBinding.jsonStringify`
- join with `"\n"`

Do not change the function contract: invalid JSON or non-array input still
returns `None`.

**Verify**: `pnpm run res:build && pnpm run res:test` -> all pass

### Step 4: Replace one-line object/null raw helpers

Clean up the remaining small raw sites in scope:

- `SchemaParser` object keys lookup
- `JsonExtractor` null/undefined comparison

Use the smallest typed expression that keeps behavior clear. Do not introduce a
new utility module unless more than one site genuinely shares it.

**Verify**: `pnpm run res:build && pnpm run res:test` -> all pass

## Done criteria

- [ ] `src/stdio/StdIn.res` no longer uses `%raw` for timeout wrappers
- [ ] `src/core/ExnUtils.res` no longer uses `%raw` for `stack` access
- [ ] `src/core/OutputWriter.res` no longer uses `%raw` for `jsonArrayToNdjson`
- [ ] `src/schema/v2/parser/SchemaParser.res` no longer uses inline `%raw` for
  `Object.keys`
- [ ] `src/schema/v2/extractors/JsonExtractor.res` no longer uses `%raw("null")`
  or `%raw("undefined")`
- [ ] `pnpm run res:build` exits 0
- [ ] `pnpm run res:test` exits 0

## STOP conditions

- Replacing timeout wrappers forces a wider timer-type refactor outside the
  in-scope files.
- Rewriting `jsonArrayToNdjson` changes error behavior or observable output.
- A verification command fails twice after a reasonable fix attempt.

## Maintenance notes

- Reviewers should reject any abstraction heavier than the removed raw wrapper.
  This is a simplification plan, not a framework plan.
