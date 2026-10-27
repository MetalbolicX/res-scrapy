# Changelog

All notable changes to this project are documented in this file.

The format is based on Keep a Changelog, and this project follows Semantic Versioning.

## [Unreleased]

### Changed
- **Breaking:** Offset-less ISO date-times now mean UTC instead of host-local time. Users relying on local-time interpretation must supply explicit offsets; output timezone settings only control formatting.
- **Breaking:** Default number cleanup now preserves scientific notation (`1e5` yields `100000`, previously `15`). Percent signs remain stripped without dividing by 100, and decimal comma still requires explicit configuration.
- **Breaking:** Count `min`/`max` constraints, including `config.defaults.count` counterparts and present-null values, now fail schema validation instead of being silently ignored.
- **Breaking:** Text fields with `join` now join all matches within each row, or broadcast one document-wide joined value in zip mode. Joined-only zip schemas produce one row when a selector matches, otherwise none; Count/List-only schemas still produce no rows.
- **Breaking:** Table mode and schema table fields omit the first pure header row inside `tbody`; mixed header/data rows, explicit schema row selectors, and no-tbody fallback behavior are unchanged.
- **Breaking:** Missing zip Boolean Presence cells now produce `false` instead of `null` when no explicit default is supplied; required checks and row-mode behavior are unchanged.
- **Breaking:** Zip extraction retains the longest ordinary scalar selector's rows, padding missing cells with their default or null instead of truncating to the first selector.

### Fixed
- Explicit null list limits now mean unlimited (numeric zero still means zero items), and null `config.rowSelector` selects zip mode like an omitted selector.
- JSON dot paths now accept an optional leading `$.` or standalone `$` for the whole value; this is not full JSONPath support.
- URL `validate:false` now preserves nonempty raw attributes on parse failure only; successfully parsed unsafe schemes remain rejected.
- The schema guide now documents attribute mode `first` as the default and `attributeOptions.joinSep`; `all` and `join` both return the same joined string.
- Discarded redirect and HTTP error response bodies are released without replacing the original fetch outcome when cancellation fails.
- Lowercase proxy environment variables now activate the optional proxy agent; routing and bypass support remain agent-owned.
- Stdin limits count UTF-8 bytes; aborted reads pause input, detach owned listeners and release timers/chunks without destroying shared stdin.
- HTTP 429/503 retries honor valid Retry-After seconds/date hints with a 60-second cap and unchanged attempt budgets.
- Fetched responses above 50 MiB are rejected without retries; unknown-length bodies are checked after buffering, not streamed under a strict memory bound.
- Fetched HTML now respects declared response charsets with a bounded meta sniff and UTF-8 fallback.
- Invalid URL templates now report their error once, without an additional misleading empty-template error.
- Stdin mode warns about ignored fetch options only when explicitly supplied, not when using defaults.
- The CLI now terminates after reporting SIGINT, SIGTERM, or a fatal runtime error instead of leaving pending work running.
- JSON file output in URL mode stays valid when pages yield no matching rows, without writing empty batches.

### Security
- Fixed the dev-only `undici` advisory GHSA-xjj6-f33q-929c (reached through `rescript-test` > `jsdom`) by raising the existing pnpm override to the patched 7.30.1.

## [1.2.0] - 2026-10-06

### Changed
- **Breaking:** Schema validation now rejects shapes it cannot build — an empty `fields` object or wrong-typed field/option values fail validation instead of producing silently broken extractions.
- **Breaking:** User headers are sent only to same-origin redirect hops (`User-Agent` is always sent). Previously every header went to every hop.
- **Breaking:** CLI scalar options are validated with explicit ranges: `--timeout` accepts 1–600 seconds and `--retry` accepts 1–10 attempts; out-of-range values are rejected with messages naming the accepted range.
- **Breaking:** Inert schema options — `numberOptions.onError`, `jsonOptions.onError`, `dateOptions.strict`, and their `config.defaults.*` counterparts — now fail validation naming the unsupported option; they were previously parsed and silently ignored.

### Fixed
- Number parsing normalizes thousands/decimal separators before stripping non-numeric characters, so mixed-separator numbers parse as configured.
- JSON/NDJSON streaming no longer emits corrupt framing when an output write fails mid-stream; the run fails fast instead.
- A 3xx response without a `Location` header is now treated as a terminal status instead of following a bogus redirect path.
- Explicit `config.limit: null` is accepted as unlimited again (regression introduced by stricter shape validation).
- The build compiles ReScript sources before bundling and fails fast on a missing `dist/`, so stale bundles cannot ship.

### Security
- Fixed dev-only advisories for `brace-expansion` (GHSA-3jxr-9vmj-r5cp, GHSA-mh99-v99m-4gvg, GHSA-rgw5-rvv9-x895, GHSA-qhr7-859c-m2p7, GHSA-6j4f-fj2g-mc7p, GHSA-q2hr-2g5m-vwhr), `undici` (GHSA-4cwx-7wf7-3272, GHSA-rfgv-xxqx-mfg5, GHSA-w293-vg96-wgc3), and `source-map-js` (GHSA-68fv-2mgg-jv7q) using minimal pnpm overrides at their patched versions; the remaining low-severity dev-only `esbuild` advisory GHSA-g7r4-m6w7-qqqr is accepted (Windows development-server arbitrary file read; production audit remains clean).

## [1.1.0] - 2026-08-04

### Added
- CI workflow (`.github/workflows/ci.yml`) to run build, tests, and bundle on pushes and pull requests.
- `--version` / `-v` CLI flag to print the package version.
- Global runtime handlers for `uncaughtException`, `unhandledRejection`, `SIGINT`, and `SIGTERM`.
- Stdin safety controls: input size cap and read timeout.
- Additional E2E and unit tests for runtime safety, Unicode handling, malformed HTML, unsafe URL schemes, and regex filter hardening.
- npm distribution with `npx res-scrapy` one-off execution support (no global install required).

### Changed
- Moved `rescript` from production dependencies to devDependencies.
- Reworked extractor default-merging paths to reduce repeated work in row and zip strategies.
- Updated schema and developer docs to align with the implemented feature set.
- Enabled bundle sourcemaps for easier debugging.
- Added `prepublishOnly` guard so `npm publish` aborts if build, tests, bundle, or date check fails.
- Removed redundant `.npmignore`; `files: ["dist"]` is now the sole source of truth for shipped contents.
- Added explicit `publishConfig.access: "public"` and `homepage` to `package.json`.

### Security
- Hardened list-filter regex handling against unsafe patterns.
- Rejected unsafe URL schemes (`javascript:`, `data:`) by default.
