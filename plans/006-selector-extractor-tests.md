# Plan 006: Add SelectorExtractor unit tests

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 8e085f5..HEAD -- src/extraction/SelectorExtractor.res`
> If changed, compare excerpts below against live code.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tests
- **Planned at**: commit `8e085f5`, 2026-06-30

## Why this matters

`SelectorExtractor.res` handles the primary `-s`/`-e` extraction path (the
most common CLI usage: `echo html | res-scrapy -s 'h1' -e text`). It has
zero dedicated tests — only covered indirectly by `MainE2E_test.res` subprocess
tests which are slow and coarse. Unit tests with injected mock `Document`
operations give fast, targeted coverage.

## Current state

### `src/extraction/SelectorExtractor.res` (51 lines)

Two functions:
- `extractElements(ctx, document, selector, extractMode, mode)` — returns
  `result<array<string>, string>`. Uses `ctx.deps.doc.documentOps` for all
  DOM operations.
- `runSelectorMode(ctx, document, ~selector, ~extractMode, ~mode, ~options)` —
  calls `extractElements` then `OutputWriter.writeOutput`.

```rescript
let extractElements: (
  AppContext.appContext,
  Document.document,
  string,
  ParseCli.extractMode,
  ParseCli.mode,
) => result<array<string>, string> = (ctx, document, selector, extractMode, mode) => {
  let extract = (el: Document.element) =>
    switch extractMode {
    | OuterHtml => Document.outerHTML(ctx.deps.doc.documentOps, el)
    | InnerHtml => Document.innerHTML(ctx.deps.doc.documentOps, el)
    | Text => Document.textContent(ctx.deps.doc.documentOps, el)
    | Attribute(name) =>
      Document.getAttribute(ctx.deps.doc.documentOps, el, name)->Option.getOr("")
    }
  switch mode {
  | Single =>
    switch Document.querySelector(ctx.deps.doc.documentOps, document, selector) {
    | None => Ok([])
    | Some(el) => Ok([extract(el)])
    }
  | Multiple =>
    Ok(
      Document.querySelectorAll(ctx.deps.doc.documentOps, document, selector)
      ->Iter.values
      ->Iter.map(el => extract(el))
      ->Iter.toArray,
    )
  }
}
```

The function takes `AppContext.appContext`, meaning tests can inject a mock
context with fake `documentOps`. This is the same DI pattern used by
`AppContext_test.res` and `MainContext_test.res`.

## Commands you will need

| Purpose   | Command                          | Expected on success |
|-----------|----------------------------------|---------------------|
| Build     | `pnpm run res:build`             | exit 0              |
| Tests     | `pnpm run res:test`              | all pass            |

## Suggested executor toolkit

- Model the test after `test/res/AppContext_test.res` — it constructs mock
  `AppContext` values with fake dependencies.
- Also reference `test/res/Document_test.res` for how `NodeHtmlDocument.operations`
  is used in tests.

## Scope

**In scope**:
- `test/res/SelectorExtractor_test.res` (create)

**Out of scope**:
- `src/extraction/SelectorExtractor.res` — no source changes
- `test/res/MainE2E_test.res` — already has coarse coverage

## Steps

### Step 1: Understand the test structure

Read these files for the patterns:
- `test/res/AppContext_test.res` — mock AppContext construction
- `test/res/Document_test.res` — document operations usage
- `test/res/ExtractionMode_test.res` — extract mode types

The test will use `NodeHtmlDocument.operations` (the production binding
for node-html-parser) as the `documentOps`, since that's the simplest way
to get a working `Document.document` from an HTML string.

### Step 2: Create the test file

Create `test/res/SelectorExtractor_test.res` with these test cases:

```rescript
open RescriptTest
open RescriptTest.Expects

// Helper: build a production AppContext with real documentOps but capture output
let makeTestCtx = () => {
  let output: ref<array<string>> = ref([])
  let exitCode: ref<option<int>> = ref(None)
  AppContext.{
    deps: AppContext.production.deps,  // real DOM bindings
    io: {
      out: msg => output.contents->Array.push(msg),
      err: msg => output.contents->Array.push(msg),
      warn: _ => (),
      exit: code => exitCode := Some(code),
    },
  }
}

// Helper: parse HTML string into a document
let parseHtml = html =>
  Document.parse(NodeHtmlDocument.operations, html)

let sampleHtml = "<div><h1>Title</h1><p>Para 1</p><p>Para 2</p></div>"

test("Single mode returns one element", () => {
  let ctx = makeTestCtx()
  let doc = parseHtml(sampleHtml)
  let result = SelectorExtractor.extractElements(ctx, doc, "h1", ParseCli.Text, ParseCli.Single)
  result->expect->toBe(Ok(["Title"]))
})

test("Multiple mode returns all matches", () => {
  let ctx = makeTestCtx()
  let doc = parseHtml(sampleHtml)
  let result = SelectorExtractor.extractElements(ctx, doc, "p", ParseCli.Text, ParseCli.Multiple)
  result->expect->toBe(Ok(["Para 1", "Para 2"]))
})

test("Single mode with no match returns empty", () => {
  let ctx = makeTestCtx()
  let doc = parseHtml(sampleHtml)
  let result = SelectorExtractor.extractElements(ctx, doc, "span", ParseCli.Text, ParseCli.Single)
  result->expect->toBe(Ok([]))
})

test("Multiple mode with no match returns empty", () => {
  let ctx = makeTestCtx()
  let doc = parseHtml(sampleHtml)
  let result = SelectorExtractor.extractElements(ctx, doc, "span", ParseCli.Text, ParseCli.Multiple)
  result->expect->toBe(Ok([]))
})

test("Extract outerHtml", () => {
  let ctx = makeTestCtx()
  let doc = parseHtml("<h1>Hello</h1>")
  let result = SelectorExtractor.extractElements(ctx, doc, "h1", ParseCli.OuterHtml, ParseCli.Single)
  // The exact format depends on node-html-parser; check it includes the tag
  switch result {
  | Ok([html]) => html->expect->toContainString("<h1>")
  | _ => fail("Expected outer HTML output")
  }
})

test("Extract innerHtml", () => {
  let ctx = makeTestCtx()
  let doc = parseHtml("<h1><span>Hi</span></h1>")
  let result = SelectorExtractor.extractElements(ctx, doc, "h1", ParseCli.InnerHtml, ParseCli.Single)
  switch result {
  | Ok([html]) => html->expect->toContainString("<span>Hi</span>")
  | _ => fail("Expected inner HTML output")
  }
})

test("Extract attribute", () => {
  let ctx = makeTestCtx()
  let doc = parseHtml("<a href=\"https://example.com\">Link</a>")
  let result = SelectorExtractor.extractElements(ctx, doc, "a", ParseCli.Attribute("href"), ParseCli.Single)
  result->expect->toBe(Ok(["https://example.com"]))
})

test("Extract missing attribute returns empty string", () => {
  let ctx = makeTestCtx()
  let doc = parseHtml("<a>Link</a>")
  let result = SelectorExtractor.extractElements(ctx, doc, "a", ParseCli.Attribute("href"), ParseCli.Single)
  result->expect->toBe(Ok([""]))
})
```

Adjust the exact assertion API to match the `rescript-test` patterns used
in existing tests. Check `test/res/TextExtractor_test.res` for the exact
`expect` syntax.

**Verify**: `pnpm run res:build && pnpm run res:test` → all 8 new tests pass.

## Test plan

The test cases above cover:
- Single mode: match, no-match
- Multiple mode: match, no-match
- All 4 extract modes: Text, OuterHtml, InnerHtml, Attribute
- Attribute edge case: missing attribute → empty string

## Done criteria

- [ ] `test/res/SelectorExtractor_test.res` exists
- [ ] `pnpm run res:build` exits 0
- [ ] `pnpm run res:test` exits 0 — all tests pass including the new ones
- [ ] At least 6 test cases covering single/multiple × match/no-match × extract modes
- [ ] No source files are modified (test-only plan)

## STOP conditions

- The `rescript-test` assertion API (`expect`, `toBe`, `toContainString`) has
  different names than used above — check `test/res/TextExtractor_test.res`
  for the actual API and adjust.
- `NodeHtmlDocument.operations` is not directly accessible from test code —
  use whatever pattern `test/res/Document_test.res` uses instead.
