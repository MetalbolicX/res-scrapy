# Plan 008: Add UrlRunner orchestration tests

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 8e085f5..HEAD -- src/url/UrlRunner.res src/core/AppContext.res`
> If changed, compare excerpts below against live code.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: tests
- **Planned at**: commit `8e085f5`, 2026-06-30

## Why this matters

`UrlRunner.res` (239 lines) orchestrates the entire URL-mode pipeline:
template parse → fetch → extract → stream/buffer output → report. It has
zero dedicated tests — only covered indirectly by slow E2E subprocess tests.
The `AppContext` DI pattern means we can inject mock dependencies for fast,
targeted unit tests that exercise the orchestration logic without real
network I/O.

## Current state

### `src/url/UrlRunner.res` (key entry point)

```rescript
let runUrlMode = async (
  ctx: AppContext.appContext,
  urlTemplate: string,
  options: ParseCli.parseOptions,
) => {
  // Parse URL template
  let urls = switch ctx.deps.doc.parseTemplate(urlTemplate)->ResultX.mapError(AppError.mapTemplateError) { ... }

  // Fetch all pages
  let fetchResults = await ctx.deps.fetch.fetchAll(urls, fetchOptions)

  // Process each fetch result
  fetchResults->Array.forEach(({url, result}) => { ... })

  // Write buffered results, print report, set exit code
}
```

The function takes `AppContext.appContext`, so tests can inject:
- `deps.doc.parseTemplate` — return a fixed list of URLs
- `deps.fetch.fetchAll` — return fixed `fetchResult` values (no network)
- `deps.doc.documentOps` — use `NodeHtmlDocument.operations` for real parsing
- `deps.serialize.*` — real JSON stringify
- `io.out/err/exit` — capture output and exit codes

### Existing test patterns

`test/res/MainContext_test.res` constructs mock `AppContext` values.
`test/res/AppContext_test.res` tests the DI container.
`test/res/FixturesIntegration_test.res` tests schema extraction with real HTML.

## Commands you will need

| Purpose   | Command                          | Expected on success |
|-----------|----------------------------------|---------------------|
| Build     | `pnpm run res:build`             | exit 0              |
| Tests     | `pnpm run res:test`              | all pass            |

## Suggested executor toolkit

- Read `test/res/AppContext_test.res` for mock context construction
- Read `test/res/MainContext_test.res` for how `io.exit` is captured
- Read `test/res/FixturesIntegration_test.res` for HTML fixture patterns

## Scope

**In scope**:
- `test/res/UrlRunner_test.res` (create)
- `test/res/helpers/` — potentially a shared mock-context helper if one
  doesn't exist (check `test/res/helpers/` first)

**Out of scope**:
- `src/url/UrlRunner.res` — no source changes (test-only plan)
- Changes to other test files

## Steps

### Step 1: Create a mock fetch helper

Create or extend a helper in `test/res/helpers/` that builds a mock
`AppContext.appContext` with controllable fetch results.

```rescript
// test/res/helpers/UrlRunnerMocks.res (or add to existing helpers)

// Builds a context where fetchAll returns the given results
// and io captures output/exit code
let makeMockCtx = (~fetchResults: array<Fetcher.fetchResult>) => {
  let output: ref<array<string>> = ref([])
  let exitCode: ref<option<int>> = ref(None)
  let ctx: AppContext.appContext = {
    deps: {
      cli: {
        parseCli: () => NodeJsBinding.Util.parseArgs({...}),  // or mock
        validateArgs: _ => Ok({...}),  // mock parseOptions
        readStdin: () => Promise.resolve(Ok("")),
        getCliVersion: () => "test",
      },
      fs: { ...AppContext.production.deps.fs },
      serialize: { ...AppContext.production.deps.serialize },
      doc: {
        documentOps: NodeHtmlDocument.operations,
        extractTable: TableExtractor.extract,
        parseTemplate: _ => Ok(["http://example.com/1", "http://example.com/2"]),
      },
      schema: { ...AppContext.production.deps.schema },
      fetch: {
        fetchAll: (_, _) => Promise.resolve(fetchResults),
      },
      perf: {
        performanceNow: () => 0.0,
      },
    },
    io: {
      out: msg => output.contents->Array.push(msg),
      err: msg => (),  // suppress stderr in tests
      warn: _ => (),
      exit: code => exitCode := Some(code),
    },
  }
  (ctx, output, exitCode)
}
```

The exact shape will depend on what `ParseCli.parseOptions` requires. Use
the simplest valid `parseOptions` record.

### Step 2: Write test cases

Create `test/res/UrlRunner_test.res` with these scenarios:

**Test A: All URLs succeed — exit 0, output produced**

```rescript
test("runUrlMode exits 0 when all URLs succeed", async () => {
  let fetchResults = [
    {url: "http://example.com/1", result: Ok("<h1>Page 1</h1>")},
    {url: "http://example.com/2", result: Ok("<h1>Page 2</h1>")},
  ]
  let options = makeOptions(~selector="h1", ~extract=ParseCli.Text, ~mode=ParseCli.Multiple)
  let (ctx, output, exitCode) = makeMockCtx(~fetchResults)
  await UrlRunner.runUrlMode(ctx, "http://example.com/{1..2}", options)
  exitCode.contents->expect->toBe(None)  // exit 0 = no exit called
  output.contents->Array.length->expect->toBe(2)  // 2 NDJSON lines
})
```

**Test B: All URLs fail — exit 1**

```rescript
test("runUrlMode exits 1 when all URLs fail", async () => {
  let fetchResults = [
    {url: "http://example.com/1", result: Error(HttpError(500, "Server Error"))},
    {url: "http://example.com/2", result: Error(NetworkError("ECONNREFUSED"))},
  ]
  let options = makeOptions(~selector="h1", ~extract=ParseCli.Text, ~mode=ParseCli.Multiple)
  let (ctx, _, exitCode) = makeMockCtx(~fetchResults)
  await UrlRunner.runUrlMode(ctx, "http://example.com/{1..2}", options)
  exitCode.contents->expect->toBe(Some(1))
})
```

**Test C: Partial success — exit 0, partial output**

```rescript
test("runUrlMode exits 0 with partial success", async () => {
  let fetchResults = [
    {url: "http://example.com/1", result: Ok("<h1>Page 1</h1>")},
    {url: "http://example.com/2", result: Error(HttpError(404, "Not Found"))},
  ]
  let options = makeOptions(~selector="h1", ~extract=ParseCli.Text, ~mode=ParseCli.Multiple)
  let (ctx, output, exitCode) = makeMockCtx(~fetchResults)
  await UrlRunner.runUrlMode(ctx, "http://example.com/{1..2}", options)
  exitCode.contents->expect->toBe(None)  // some succeeded
  output.contents->Array.length->expect->toBe(1)  // only 1 NDJSON line
})
```

**Test D: Stdout NDJSON streaming — one line per row**

```rescript
test("runUrlMode streams NDJSON to stdout", async () => {
  let fetchResults = [
    {url: "http://example.com/1", result: Ok("<ul><li>A</li><li>B</li></ul>")},
  ]
  let options = makeOptions(~selector="li", ~extract=ParseCli.Text, ~mode=ParseCli.Multiple)
  let (ctx, output, _) = makeMockCtx(~fetchResults)
  await UrlRunner.runUrlMode(ctx, "http://example.com/1", options)
  // 2 <li> elements → 2 NDJSON lines
  output.contents->Array.length->expect->toBe(2)
})
```

**Test E: Template parse error — exit 1**

```rescript
test("runUrlMode exits 1 on invalid URL template", async () => {
  // Make parseTemplate return an error
  let ctx = makeMockCtxWithErrorTemplate()
  let options = makeOptions(~selector="h1", ~extract=ParseCli.Text)
  await UrlRunner.runUrlMode(ctx, "invalid{{template", options)
  exitCode.contents->expect->toBe(Some(1))
})
```

**Verify**: `pnpm run res:build && pnpm run res:test` → all 5 new tests pass.

### Step 3: Handle the `parseOptions` construction

The tests need a valid `ParseCli.parseOptions` record. The easiest way is
to call `ParseCli.runArgsValidation` with a mock `cliValues` object:

```rescript
let makeOptions = (~selector, ~extract, ~mode=ParseCli.Single) => {
  let values: NodeJsBinding.Util.cliValues = {
    // ... construct with the minimum required fields
  }
  switch ParseCli.runArgsValidation(values) {
  | Ok(opts) => opts
  | Error(e) => fail("Failed to build test options")
  }
}
```

Alternatively, construct the record directly (bypass validation). See
`test/res/ParseCli_test.res` for how `cliValues` is constructed.

**Verify**: `pnpm run res:test` → all pass.

## Test plan

5 test cases covering:
1. All URLs succeed → exit 0, correct output count
2. All URLs fail → exit 1
3. Partial success → exit 0, partial output
4. NDJSON streaming → one line per row
5. Template parse error → exit 1

## Done criteria

- [ ] `test/res/UrlRunner_test.res` exists
- [ ] `pnpm run res:build` exits 0
- [ ] `pnpm run res:test` exits 0 — all tests pass including the 5 new ones
- [ ] Tests use mock fetch (no real network calls)
- [ ] At least one test verifies exit code on failure
- [ ] No source files are modified

## STOP conditions

- `AppContext.production.deps` fields cannot be spread (`...`) in ReScript
  records — if spread syntax fails, construct the full record explicitly.
- `ParseCli.parseOptions` has required fields that are difficult to mock —
  use `ParseCli.runArgsValidation` with mock `cliValues` instead.
- `runUrlMode` is too tightly coupled to test in isolation (e.g., it calls
  non-injected functions) — if so, report this as a finding and test at
  the `mainWithContext` level instead.

## Maintenance notes

- The mock `fetchAll` returns `Promise.resolve(results)` synchronously.
  This means timing-dependent behavior (start limiter, semaphore) is not
  exercised. For concurrency testing, see Plan 007.
- These tests are the safety net for Plans 004 (NDJSON error propagation)
  and 010 (streaming JSON output). Run them after those plans land.
