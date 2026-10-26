# Changelog

All notable changes to this project are documented in this file.

The format is based on Keep a Changelog, and this project follows Semantic Versioning.

## [Unreleased]

### Fixed
- Invalid URL templates now report their error once, without an additional misleading empty-template error.
- Stdin mode warns about ignored fetch options only when explicitly supplied, not when using defaults.
- The CLI now terminates after reporting SIGINT, SIGTERM, or a fatal runtime error instead of leaving pending work running.
- JSON file output in URL mode stays valid when pages yield no matching rows, without writing empty batches.

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
