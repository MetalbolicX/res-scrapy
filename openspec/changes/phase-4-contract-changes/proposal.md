# Proposal: Phase 4 — URL pipeline JSON.t threading + unified output errors

## Intent

The URL-mode pipeline currently serializes extraction output to a JSON
string in `extractFromDocument`, then parses it back to `JSON.t` inside
`processOne` for row counting and routing, only to serialize again at the
write boundary. That round-trip is wasted work for every per-URL row
batch and is the source of a latent failure mode ("Failed to parse
extraction result") that fires when extraction happens to produce
un-parseable text.

Output error reporting is split: `OutputWriter` uses
`result<unit, AppError.appError>` (typed, with `AppError.WriteError`),
but `UrlOutputWriter` uses `result<unit, string>` (raw string), except
for `writeFileJsonSync` which already uses `AppError.appError`. The
inconsistency forces UrlRunner to convert string errors back into
counted warnings, and prevents typed error matching at module
boundaries.

This change threads structured `JSON.t` end-to-end through URL mode and
collapses all URL-output error returns onto the existing
`AppError.appError` contract.

## Scope

### In Scope
- `extractFromDocument` returns `result<JSON.t, string>`; rows are wrapped
  into `JSON.t` at the source (table / schema / selector).
- Remove the `NodeJsBinding.jsonParse` call in `processOne`.
- `UrlOutputWriter` returns `result<unit, AppError.appError>` across all
  helpers; `emitWriteError` builds `AppError.WriteError`.
- `UrlRunner.routeOutput` propagates `AppError.appError`; the
  `writeFailures` warning string uses `AppError.toMessage`.
- Regression tests cover nested objects, arrays, nulls, and error
  reporting paths.

### Out of Scope
- Changing `OutputWriter` behaviour (already typed).
- Changing fetch-side error contracts (`Fetcher.fetchError`).
- Adding new output targets or formats.
- Schema v2 internal contract changes (only the URL-mode boundary).

## Capabilities

### New Capabilities
- `url-mode-pipeline`: end-to-end `JSON.t` data flow for URL mode; no
  stringify-then-parse of extraction output. Becomes
  `openspec/specs/url-mode-pipeline/spec.md`.

### Modified Capabilities
- `output-error-contract`: unify URL-output errors on
  `AppError.appError`. Delta spec lives in
  `openspec/changes/phase-4-contract-changes/specs/output-error-contract/spec.md`.

## Approach

`extractFromDocument` is the seam between extraction and routing. We
change its return type to `result<JSON.t, string>` and convert at the
producer:

| Setup | Current | New |
|-------|---------|-----|
| `TableSetup(selector)` | `stringifyTableRows` → string | `JSON.Encode.array(rows->Array.map(JSON.Encode.object))` |
| `SchemaSetup(schema)` | `stringifyJson(json)` | passthrough (already JSON.t) |
| `SelectorSetup({selector, ...})` | `stringifyStrings(contents)` | `JSON.Encode.array(contents->Array.map(JSON.Encode.string))` |

`processOne` deletes its `jsonParse` branch and the
"Failed to parse extraction result" failure path entirely.

For errors, `emitWriteError` is rewritten to produce
`AppError.WriteError(...)`; every other helper's return type becomes
`result<unit, AppError.appError>`. `UrlRunner.routeOutput` calls
`AppError.toMessage` only for the human-readable warning printed by
`ctx.io.err`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `src/url/UrlRunner.res` | Modified | extractFromDocument return type; remove jsonParse; AppError propagation |
| `src/url/UrlOutputWriter.res` | Modified | All helpers return `result<_, AppError.appError>` |
| `test/res/UrlOutputWriter_test.res` | Modified | Update assertions for typed errors |
| `test/res/UrlRunner_test.res` | Modified | Add nested-object / null / array coverage |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `JSON.Encode.array` of `array<dict<string>>` differs from old `JSON.stringify` round-trip | Low | Reuse `extractTable` output structure; verify with regression tests |
| `AppError.WriteError` collides with messages from `OutputWriter` | Low | `WriteError` already used; just route UrlOutputWriter through same constructor |
| Test surface area increases | Med | Keep new tests scoped to data preservation + error reporting |

## Rollback Plan

Revert the change folder (`openspec/changes/phase-4-contract-changes/`),
re-checkout the previous `UrlRunner.res` and `UrlOutputWriter.res` from
`git`, rebuild. No persisted state changes; the public CLI surface is
unchanged.

## Dependencies

- Phase 3 (`processOne` decomposition) — DONE
- `AppError.WriteError` constructor — already exists in `AppError.res`

## Success Criteria

- [ ] `grep -c jsonParse src/url/UrlRunner.res` = 0
- [ ] `extractFromDocument: result<JSON.t, string>` (no `string`)
- [ ] All `UrlOutputWriter` helpers return `result<_, AppError.appError>`
- [ ] Regression tests cover nested objects, arrays, nulls, and error reporting
- [ ] `pnpm run release:check` passes (456+ tests, build clean, date parity)
