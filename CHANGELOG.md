# Changelog

All notable changes to this project are documented in this file.

The format is based on Keep a Changelog, and this project follows Semantic Versioning.

## [Unreleased]

### Added
- CI workflow (`.github/workflows/ci.yml`) to run build, tests, and bundle on pushes and pull requests.
- `--version` / `-v` CLI flag to print the package version.
- Global runtime handlers for `uncaughtException`, `unhandledRejection`, `SIGINT`, and `SIGTERM`.
- Stdin safety controls: input size cap and read timeout.
- Additional E2E and unit tests for runtime safety, Unicode handling, malformed HTML, unsafe URL schemes, and regex filter hardening.

### Changed
- Moved `rescript` from production dependencies to devDependencies.
- Reworked extractor default-merging paths to reduce repeated work in row and zip strategies.
- Updated schema and developer docs to align with the implemented feature set.
- Enabled bundle sourcemaps for easier debugging.

### Security
- Hardened list-filter regex handling against unsafe patterns.
- Rejected unsafe URL schemes (`javascript:`, `data:`) by default.
