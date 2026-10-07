# Changelog

All notable changes to this project are documented in this file.

The format is based on Keep a Changelog, and this project follows Semantic Versioning.

## [Unreleased]

### Security
- Fixed dev-only advisories for `brace-expansion` (GHSA-3jxr-9vmj-r5cp, GHSA-mh99-v99m-4gvg, GHSA-rgw5-rvv9-x895, GHSA-qhr7-859c-m2p7, GHSA-6j4f-fj2g-mc7p, GHSA-q2hr-2g5m-vwhr), `undici` (GHSA-4cwx-7wf7-3272, GHSA-rfgv-xxqx-mfg5, GHSA-w293-vg96-wgc3), and `source-map-js` (GHSA-68fv-2mgg-jv7q) using minimal pnpm overrides at their patched versions; the remaining low-severity dev-only `esbuild` advisory GHSA-g7r4-m6w7-qqqr is accepted (Windows development-server arbitrary file read; production audit remains clean).

### Changed
- Schema configs using `number.onError`, `date.strict`, or `json.onError` (including `config.defaults.number.onError` and `config.defaults.datetime.strict`) now fail validation with an error naming the unsupported option; these keys were previously silently ignored.

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

## [Unreleased]
