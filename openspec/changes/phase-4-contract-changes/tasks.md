# Tasks: Phase 4 — URL Pipeline JSON.t Threading + Output Error Unification

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~80–110 (src + tests) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Full change: extractFromDocument JSON.t + UrlOutputWriter AppError + tests | PR 1 | `pnpm run res:test` | `node dist/main.mjs --help` | Revert the 2 src files + tests |

## Phase 1: Producer (extractFromDocument)

- [x] 1.1 In `src/url/UrlRunner.res`: change `extractFromDocument` return type from `result<string, string>` to `result<JSON.t, string>`
- [x] 1.2 `TableSetup` branch: wrap `extractTable` rows with `JSON.Encode.array(rows->Array.map(JSON.Encode.object))` (values encoded as `JSON.Encode.string`)
- [x] 1.3 `SchemaSetup` branch: drop `stringifyJson` mapping (return JSON.t directly); keep `formatSchemaFailureReason` for error path
- [x] 1.4 `SelectorSetup` branch: wrap `extractElements` contents with `JSON.Encode.array(contents->Array.map(JSON.Encode.string))`

## Phase 2: Writer Error Contract

- [x] 2.1 In `src/url/UrlOutputWriter.res`: rewrite `emitWriteError` to return `result<unit, AppError.appError>` and build `AppError.WriteError(msg)`
- [x] 2.2 `appendNdjsonToFile`: change return type to `promise<result<unit, AppError.appError>>`; reuse `emitWriteError`
- [x] 2.3 `beginJsonArraySync`: change return type to `result<unit, AppError.appError>`
- [x] 2.4 `appendJsonRowAsync`: change return type to `promise<result<unit, AppError.appError>>`
- [x] 2.5 `endJsonArraySync`: change return type to `result<unit, AppError.appError>`
- [x] 2.6 `writeFileJsonSync`: no type change (already returns `AppError.appError`); verify it still type-checks

## Phase 3: Wiring (UrlRunner)

- [x] 3.1 In `src/url/UrlRunner.res` `processOne`: delete `NodeJsBinding.jsonParse(jsonText)` branch and the `"Failed to parse extraction result"` failure path
- [x] 3.2 `routeOutput`: update internal helper call signatures to expect `AppError.appError`; on `Error(appErr)`, increment `state.writeFailures` and emit warning via `AppError.toMessage(appErr)`
- [x] 3.3 Update JSON-close logic (lines after `processAll`): error handlers now operate on `AppError.appError`; final warning path unchanged
- [x] 3.4 Run `pnpm run res:build`; resolve any remaining type errors

## Phase 4: Tests

- [x] 4.1 In `test/res/UrlRunner_test.res`: add `extractFromDocument` regression test asserting nested objects preserved through pipeline
- [x] 4.2 Add test asserting `JSON.Encode.null` passes through unchanged (no `""` conversion)
- [x] 4.3 Add test asserting `JSON.Array` row count (`countRows` on 3-element array returns `3`)
- [x] 4.4 In `test/res/UrlOutputWriter_test.res`: update assertions on `appendNdjsonToFile` failure to expect `AppError.WriteError(...)` shape
- [x] 4.5 Update assertions on `beginJsonArraySync`, `appendJsonRowAsync`, `endJsonArraySync` failure paths
- [x] 4.6 Verify `Warning: ...` prefix on emitted `err` calls

## Phase 5: Verification

- [x] 5.1 Run `pnpm run res:test`; confirm 456+ tests pass
- [x] 5.2 Run `pnpm run release:check`; confirm bundle + date parity
- [x] 5.3 Grep verification: `grep -c jsonParse src/url/UrlRunner.res` returns `0`
- [x] 5.4 Grep verification: no `result<_, string>` returns remain in `src/url/UrlOutputWriter.res` (all converted to `AppError.appError`)

(End of file - total 67 lines)
