# Plan 014: Remove the smallest duplication and hot-path waste

> **Executor instructions**: Keep this phase mechanical. Do not change contracts. If a change starts to affect another module's public type, stop and move that work to Phase 4.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/013-baseline-verification.md
- **Category**: tech-debt / perf / correctness
- **SDD**: No
- **Planned at**: commit `df9000c`, 2026-07-23

## Why this matters

These are the cheapest wins: they cut duplicate code, remove repeated work in hot loops, and surface hidden parse/config errors without reshaping the architecture.

## Current state

- `src/core/OutputWriter.res`, `src/url/UrlOutputWriter.res` — repeated error-message construction.
- `src/schema/v2/executor/{RowExtractor,ZipExtractor}.res` — repeated work inside row loops.
- `src/schema/v2/utils/date/parseDate.mts` — repeated regex construction for the same format.
- `src/schema/v2/extractors/ExtractorRegistry.res` — manual list dispatch alongside visitor-based dispatch.
- `src/schema/v2/parser/OptionsParser.res`, `src/schema/v2/extractors/JsonExtractor.res` — silent fallbacks.

## Steps

### Step 1: Deduplicate output error formatting

- Extract a private helper in `OutputWriter.res` and a single warning helper in `UrlOutputWriter.res`.

**Verify**: existing output tests still pass; message text remains stable.

### Step 2: Remove repeated extractor hot-loop work

- Precompute `isMultiElementType` once in `RowExtractor.res`; avoid `Dict.fromArray` per row in both extractors; pre-build ZipExtractor aggregate pairs.

**Verify**: row/extractor tests pass and no loop-local `isMultiElementType` calls remain.

### Step 3: Hoist/cached date regex construction

- Cache the format regex in `parseDate.mts` and hoist the sorted token list.

**Verify**: date tests pass; repeated same-format parsing no longer recompiles the regex.

### Step 4: Align registry dispatch and surface silent errors

- Make `extractValueList` use the visitor path consistently; make OptionsParser and JsonExtractor report errors instead of silently falling back.

**Verify**: registry and parser/extractor tests cover the new failure paths.

## Deliverables

- [ ] Output error formatting deduped
- [ ] Hot-loop allocations reduced in RowExtractor/ZipExtractor
- [ ] Date regex caching in place
- [ ] ExtractorRegistry dispatch consistent
- [ ] Silent parser/extractor failures become visible

## STOP conditions

- Any step requires changing `AppError` or `UrlOutputWriter` return types.
- A change starts to affect UrlRunner orchestration or output contracts.
