# Plan 016: Split UrlRunner into focused steps

> **Executor instructions**: This is a structural refactor. Keep the behavior identical and stop if you discover the output-routing shape needs a new contract.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/013-baseline-verification.md, plans/014-quick-wins.md, plans/015-local-refactors.md
- **Category**: refactor
- **SDD**: Optional design-only
- **Planned at**: commit `df9000c`, 2026-07-23

## Why this matters

`processOne` currently mixes fetch handling, document parsing, extraction, and output routing. Splitting those responsibilities makes the next contract changes safer.

## Current state

- `src/url/UrlRunner.res` — nested fetch → parse → extract → route flow.
- `test/res/UrlRunner_test.res`, `test/res/OutputPipeline_test.res` — characterization tests for current behavior.

## Steps

### Step 1: Add characterization coverage

- Lock down the current output order, error handling, and per-URL behavior before refactoring the coordinator.

**Verify**: the new characterization tests fail only if UrlRunner behavior changes.

### Step 2: Split extraction from routing

- Extract a focused function for `extractFromDocument` and a separate function for `routeOutput`.

**Verify**: `processOne` becomes a thin coordinator and still passes the existing UrlRunner tests.

### Step 3: Keep output routing simple unless a strategy is truly needed

- Only introduce an `OutputRouting` module if it reduces branching without creating a second abstraction layer.

**Verify**: if no strategy is added, the routing helper stays small and explicit.

### Step 4: Re-run the URL regression suite

- Confirm output ordering, failure accounting, and serialization behavior are unchanged.

**Verify**: `pnpm run res:test` passes for UrlRunner and output pipeline suites.

## Deliverables

- [ ] `processOne` no longer has deep nesting
- [ ] Extraction and routing are separate functions
- [ ] Characterization tests prove behavior stayed stable
- [ ] No output/data contract changed yet

## STOP conditions

- The refactor requires changing `AppError` or the output writer signatures.
- A strategy abstraction starts to feel speculative instead of simplifying the code.
