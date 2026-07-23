# Design: Phase 4 — URL Pipeline JSON.t Threading + Output Error Unification

## Technical Approach

Two coupled refactors with one shared seam — `UrlRunner.extractFromDocument`:

1. **Producer-side JSON.t conversion.** Each `extractionSetup` branch
   in `extractFromDocument` builds a `JSON.t` value at the source. No
   intermediate string is ever materialised for routing purposes.

2. **Typed errors at the writer boundary.** `UrlOutputWriter.emitWriteError`
   constructs `AppError.WriteError(msg)`; every helper's return type
   becomes `result<_, AppError.appError>`. `UrlRunner.routeOutput` propagates
   the typed error and uses `AppError.toMessage` only for the
   user-visible warning.

## Architecture Decisions

### Decision: Convert at the extraction seam, not at the writer

**Choice**: Each `extractionSetup` branch builds its own `JSON.t` value.
**Alternatives considered**: (a) Convert in `routeOutput` (rejected —
duplicates the three branches outside the setup they belong to);
(b) keep `JSON.Encode.object(dict)` and let writer convert
(rejected — leaks ReScript `dict` into the writer).
**Rationale**: The setup is the producer; it owns the shape. Writer
stays domain-agnostic.

### Decision: Use `JSON.Encode.array` + per-value encoding for table rows

**Choice**:
```rescript
| TableSetup(selector) =>
  ctx.deps.doc.extractTable(document, selector)->Result.map(rows =>
    JSON.Encode.array(rows->Array.map(row =>
      JSON.Encode.object(Dict.toArray(row)->Array.map(((k, v)) =>
        (k, JSON.Encode.string(v))
      ))
    ))
  )
```
**Alternatives**: (a) Reuse `ctx.deps.serialize.stringifyTableRows` and
parse back (rejected — re-creates the round-trip we're removing);
(b) introduce a new `dict<string> -> JSON.t` helper in `AppContext.deps`
(rejected — only one call site, helper would be premature abstraction).
**Rationale**: `extractTable` returns `array<dict<string>>` per its
current contract; direct encoding preserves order and avoids the
hidden stringify step.

### Decision: Wrap selector strings with `JSON.Encode.string`

**Choice**: `JSON.Encode.array(contents->Array.map(JSON.Encode.string))`.
**Rationale**: `extractElements` returns `array<string>`; encoding
each value with `JSON.Encode.string` matches existing usage in
`ListExtractor.res:120`.

### Decision: Reuse `AppError.WriteError` for `UrlOutputWriter`

**Choice**: All `UrlOutputWriter` helpers return
`result<unit, AppError.appError>`. `emitWriteError` builds the typed
error and emits the warning via `err`.
**Alternatives**: (a) New `OutputError(...)` constructor (rejected —
`WriteError` already exists and is used by `OutputWriter.writeError`,
so we get consistency for free); (b) keep raw string and convert at
`UrlRunner` boundary (rejected — leaks untyped contract through the
public surface of `UrlOutputWriter`).
**Rationale**: One canonical error shape across the output boundary.

### Decision: `AppError.toMessage` only at the warning site

**Choice**: `UrlRunner.routeOutput` returns
`Error(appErr: AppError.appError)` to the caller. The final
exit-time warning in `runUrlMode` formats via `AppError.toMessage`
only for the `"Warning: N output write(s) failed"` line.
**Rationale**: Typed errors flow through the pipeline; human strings
are reserved for the final user message.

## Data Flow

```
Before (round-trip):
  extractTable (array<dict>) ──▶ stringifyTableRows (string) ──▶ jsonParse (JSON.t) ──▶ routeOutput (stringify at write)

After (no round-trip):
  extractTable (array<dict>) ──▶ JSON.Encode.array/object (JSON.t) ──▶ routeOutput (stringify at write)
  applySchema (JSON.t)        ──▶ passthrough                       ──▶ routeOutput
  extractElements (array<string>) ──▶ JSON.Encode.array/string (JSON.t) ──▶ routeOutput
```

Error flow:

```
Before: emitWriteError → err("Warning: ...") → Error(string) → caller increments counter
After:  emitWriteError → err("Warning: " + toMessage(appErr)) → Error(AppError.WriteError) → caller increments counter
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `src/url/UrlRunner.res` | Modify | `extractFromDocument` returns `result<JSON.t, string>`; remove `jsonParse` in `processOne`; `routeOutput` propagates `AppError.appError` |
| `src/url/UrlOutputWriter.res` | Modify | All helpers return `result<_, AppError.appError>`; `emitWriteError` builds `AppError.WriteError` |
| `src/core/AppError.res` | No change | `WriteError` already exists |
| `test/res/UrlRunner_test.res` | Modify | Add regression tests: nested objects, nulls, arrays; verify no `"Failed to parse"` failure path |
| `test/res/UrlOutputWriter_test.res` | Modify | Update assertions to match `AppError.appError`; verify warning prefix |

## Interfaces / Contracts

```rescript
// New
let extractFromDocument: (
  ~setup: extractionSetup,
  ~document: NodeHtmlParserBinding.htmlElement,
  ~ctx: AppContext.appContext,
) => result<JSON.t, string>

// New (per UrlOutputWriter helpers)
let appendNdjsonToFile: (
  ~appendFile: (string, string) => promise<unit>,
  ~err: string => unit,
  ~stringifyJson: JSON.t => string,
  ~path: string,
  ~json: JSON.t,
) => promise<result<unit, AppError.appError>>

// Internal helper (signature change)
let emitWriteError: (
  ~err: string => unit,
  ~path: string,
  ~operation: string,
  ~exn: exn,
) => result<unit, AppError.appError>
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | `extractFromDocument` returns `JSON.t` for all 3 setups | Inspect return type, compare against expected `JSON.Encode.*` |
| Unit | Nested objects, nulls, arrays preserved through `processOne` | Drive a stub `AppContext`, assert `routeOutput` receives the same `JSON.t` |
| Unit | `UrlOutputWriter` returns `AppError.WriteError` on file failure | Mock `appendFile` / `writeFileSync` to throw, assert error shape |
| Unit | Warning string prefix `"Warning: "` preserved | Capture `err` calls |
| Integration | `pnpm run res:test` passes (456+ tests) | Existing suite |
| E2E | `pnpm run release:check` passes | Bundle + date parity |

## Threat Matrix

`N/A` — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary is touched by this change.

## Migration / Rollout

No migration required. The CLI surface is unchanged. Old tests that
asserted `"Failed to parse extraction result"` are removed alongside
the code path they exercised.

## Open Questions

None — the design is fully constrained by the proposal and specs.
