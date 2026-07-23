# Plan 017: Change URL data-flow and output error contracts

> **Executor instructions**: Treat this as the contract-change phase. Get the design approved before implementation. Do not start until the Phase 3 refactor is in place.

## Status

- **Priority**: P1
- **Effort**: M/L
- **Risk**: MED
- **Depends on**: plans/016-structural-url-runner.md
- **Category**: architecture / perf / correctness
- **SDD**: Yes
- **Planned at**: commit `df9000c`, 2026-07-23

## Why this matters

This phase removes the stringify→parse round-trip and unifies output error contracts. Both change how modules talk to each other, so they need a written design and explicit verification.

## Current state

- `src/url/UrlRunner.res` — currently stringifies extraction output and parses it again for counting/routing.
- `src/core/OutputWriter.res`, `src/url/UrlOutputWriter.res` — output error types are split.
- `src/core/AppError.res` — current error model used by the rest of the app.

## Steps

### Step 1: Write the contract design first

- Define the structured per-URL data flow and the unified output error shape before touching code.

**Verify**: design review explicitly approves the new contract.

### Step 2: Remove the stringify→parse round-trip

- Thread structured JSON through UrlRunner and stringify only at the final output boundary.

**Verify**: `UrlRunner.res` no longer re-parses the serialized JSON; row counting still works.

### Step 3: Unify output error types

- Migrate `UrlOutputWriter` and its callers to one output-error contract.

**Verify**: all URL-mode writers use the same error shape and no ad hoc string contract remains at module boundaries.

### Step 4: Add regression coverage

- Cover nested objects, arrays, nulls, and error reporting in the updated pipeline.

**Verify**: `pnpm run res:test` and `pnpm run release:check` pass.

## Deliverables

- [ ] Design approval recorded before implementation
- [ ] JSON stays structured until the write boundary
- [ ] Output error contract is unified
- [ ] Regression tests prove data preservation and error reporting

## STOP conditions

- The design review rejects the new contract shape.
- The implementation starts requiring a broader API migration than planned.
