# Plan 013: Fix `jsonParse` typing and remove redundant `Obj.magic`

> **Executor instructions**: Follow this plan step by step. Run every
> verification command before moving on. If a STOP condition occurs, stop and
> report; do not improvise.
>
> **Drift check (run first)**:
> `git diff --stat 59685ea..HEAD -- src/bindings/NodeJsBinding.res test/res/helpers/TestHelpers.res src/schema/v2/parser/SchemaParser.res src/schema/v2/extractors/JsonExtractor.res src/cli/Cli.res test/res/ListExtractor_test.res`
> If any in-scope file changed, compare the excerpts below against live code. If
> they no longer match materially, stop and refresh the plan.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `59685ea`, 2026-06-30

## Why this matters

`src/bindings/NodeJsBinding.res` currently defines `jsonParse` as
`string => option<'a>`. That polymorphic return type leaks into callers and is
the main reason `Obj.magic` appears across parsing, CLI, extractor, and test
helpers. This plan narrows the boundary to `JSON.t`, removes obviously
redundant casts, and leaves only the genuinely unavoidable open-object cast
sites for later isolation.

## Current state

- `src/bindings/NodeJsBinding.res:144-150`
  ```rescript
  let jsonParse = (raw: string): option<'a> => {
    try {
      Some((%raw("JSON.parse"): string => 'a)(raw))
    } catch {
    | _ => None
    }
  }
  ```
- `test/res/helpers/TestHelpers.res:21-48`
  ```rescript
  let jsonFromString: string => JSON.t = raw =>
    switch NodeJsBinding.jsonParse(raw) {
    | Some(v) => Obj.magic(v)
    | None => { failWith("Invalid JSON literal in test"); JSON.Encode.null }
    }

  let arrayFromJsonString: string => array<JSON.t> = raw =>
    switch NodeJsBinding.jsonParse(raw) {
    | Some(v) => Obj.magic(v)
    | None => { failWith("Invalid JSON literal in test"); [] }
    }
  ```
- `src/schema/v2/parser/SchemaParser.res:47-48`
  ```rescript
  let parseSchema: 'a => result<schema, schemaError> = jsonValue => {
    let raw: {..} = Obj.magic(jsonValue)
  ```
- `src/schema/v2/extractors/JsonExtractor.res:107`
  ```rescript
  | Some(v) => Some(Obj.magic(v))
  ```
- `src/cli/Cli.res:25`
  ```rescript
  let pkg: {..} = Obj.magic(json)
  ```
- `test/res/ListExtractor_test.res:10`
  ```rescript
  arr->Array.map(node => NodeJsBinding.jsonStringify(Obj.magic(node)))
  ```

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Build | `pnpm run res:build` | exit 0 |
| Tests | `pnpm run res:test` | all pass |
| Coverage smoke | `pnpm run res:coverage` | all pass |

## Scope

**In scope**:

- `src/bindings/NodeJsBinding.res`
- `test/res/helpers/TestHelpers.res`
- `src/schema/v2/parser/SchemaParser.res`
- `src/schema/v2/extractors/JsonExtractor.res`
- `src/cli/Cli.res`
- `test/res/ListExtractor_test.res`

**Out of scope**:

- `test/res/MainE2E_test.res` broader cast cleanup
- `%raw` replacements unrelated to `jsonParse`
- introducing a third-party decoder library

## Steps

### Step 1: Narrow `jsonParse` to `JSON.t`

In `src/bindings/NodeJsBinding.res`, change `jsonParse` from
`string => option<'a>` to `string => option<JSON.t>`.

Keep the current try/catch behavior and inline `%raw("JSON.parse")` boundary.
This plan is about type narrowing, not replacing that `%raw` site yet.

**Verify**: `pnpm run res:build` -> exit 0

### Step 2: Remove redundant casts in `TestHelpers`

In `test/res/helpers/TestHelpers.res`, remove `Obj.magic` in:

- `jsonFromString`
- `arrayFromJsonString`

For `objectFromJsonString`, prefer a single explicit coercion helper if the code
still needs `{..}` rather than scattering `Obj.magic` inline.

Do not change test behavior or failure messages.

**Verify**: `pnpm run res:build` -> exit 0

### Step 3: Remove obviously redundant `Obj.magic` from production callers

Update these call sites so the type system carries `JSON.t` directly:

- `src/schema/v2/extractors/JsonExtractor.res:107`
- `test/res/ListExtractor_test.res:10`

For `src/cli/Cli.res` and `src/schema/v2/parser/SchemaParser.res`, only remove
the cast if the resulting code stays readable. A single centralized coercion to
`{..}` is acceptable because open JS objects are a real type boundary here.

**Verify**: `pnpm run res:build` -> exit 0

### Step 4: Decide and isolate the `{..}` boundary

Pick one of these two shapes and apply it consistently in the in-scope files:

1. function signatures accept `{..}` and callers perform one explicit coercion
2. functions accept `JSON.t` and immediately convert once at the top

Do not leave multiple ad-hoc `Obj.magic` calls in different branches.

**Verify**: `pnpm run res:build && pnpm run res:test` -> all pass

## Test plan

- Use the existing test suite as regression coverage.
- Pay attention to parser tests, CLI tests, and JSON extractor tests.
- If any inference becomes less obvious after removing casts, add the smallest
  clarifying type annotation rather than reintroducing `Obj.magic`.

## Done criteria

- [ ] `pnpm run res:build` exits 0
- [ ] `pnpm run res:test` exits 0
- [ ] `test/res/helpers/TestHelpers.res` no longer uses `Obj.magic` for
  `jsonFromString` or `arrayFromJsonString`
- [ ] `src/schema/v2/extractors/JsonExtractor.res` no longer uses
  `Some(Obj.magic(v))`
- [ ] `test/res/ListExtractor_test.res` no longer wraps `node` in `Obj.magic`
- [ ] Any remaining `Obj.magic` in the in-scope files is a single explicit
  `{..}` boundary, not repeated ad-hoc casts

## STOP conditions

- Changing `jsonParse` to `option<JSON.t>` breaks unrelated modules outside the
  in-scope list.
- ReScript requires more than one repeated `Obj.magic` to keep `{..}` access
  working cleanly.
- A verification command fails twice after a reasonable fix attempt.

## Maintenance notes

- If a future refactor introduces typed decoders, that should replace the
  remaining `{..}` coercion rather than stacking on top of it.
- Reviewers should be strict about not accepting new `Obj.magic` in the touched
  files unless it marks a single named boundary.
