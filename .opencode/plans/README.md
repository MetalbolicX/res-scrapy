# FFI Refactor Plans

Generated on 2026-06-30 from commit `59685ea`.

These plans are the polished execution set for reducing `Obj.magic` and `%raw`
usage in the ReScript source while preserving the repo's current constraint of
zero external ReScript runtime dependencies.

## Execution Order

| Plan | Title | Priority | Effort | Depends on | Status |
|------|-------|----------|--------|------------|--------|
| 013 | Fix `jsonParse` typing and remove redundant `Obj.magic` | P1 | S | — | TODO |
| 014 | Replace easy `%raw` wrappers with typed bindings | P1 | S | — | TODO |
| 015 | Centralize test JSON coercion and trim E2E `Obj.magic` | P2 | M | 013 | TODO |
| 016 | Refactor remaining high-value FFI islands and document exceptions | P2 | M | 013, 014 | TODO |

Status values: TODO | IN PROGRESS | DONE | BLOCKED | REJECTED

## Dependency Notes

- Plan 013 goes first because `NodeJsBinding.jsonParse` is the root cause of the
  broadest `Obj.magic` spread.
- Plan 014 is independent and can land in parallel, but Plan 016 assumes its
  low-risk replacements are already finished.
- Plan 015 depends on 013 because the new test helpers should consume the typed
  `jsonParse` result rather than preserve the old polymorphic shape.

## Deliberate Exceptions

Even after these plans land, some FFI should remain:

- `import.meta.url` blocks in `src/Main.res` and `src/cli/Cli.res`
- dynamic `import()` in `src/url/Fetcher.res`
- a small, explicit `JSON.t` -> `{..}` coercion boundary where open JS objects
  are genuinely required
- runtime shape assertions in tests where the point of the test is JS behavior

Those sites are not failures. The goal is to isolate them, name them, and avoid
casual spread.
