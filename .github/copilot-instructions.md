# Copilot instructions — res-scrapy

This file helps Copilot sessions quickly understand, build, run, and edit the res-scrapy repository.

## Build, run, test, and lint

- Install dependencies: `pnpm install` (pnpm is the recommended package manager).
- Build (Rescript compile + bundle): `pnpm run build`  (runs `rescript && rolldown -c`).
- ReScript only (compile in-source): `pnpm run res:build`.
- Watch ReScript sources during development: `pnpm run res:dev`.
- Clean ReScript artifacts: `pnpm run res:clean`.
- Run locally without bundling: `node src/Main.res.mjs` or `pnpm start`.

Notes:
- There are no automated test or lint scripts in package.json. Use the examples in `examples/` for manual verification.
- Manual single-run examples (use from repo root):
  - Selector-based single extraction:
    `cat examples/sample.html | node src/Main.res.mjs -s '.product-title' -e text`
  - Schema-driven extraction using a file:
    `cat examples/sample.html | node src/Main.res.mjs --schemaPath examples/schema-product.json`

## High-level architecture (big picture)

- Language & runtime:
  - Implemented in ReScript. Sources live under `src/` and are compiled in-source to `.res.mjs` files per `rescript.json`.
  - Node engine required: `>=22.0.0` (see package.json `engines`).
- Entry point: `src/Main.res` (compiled to `src/Main.res.mjs`) — it:
  1. Parses CLI flags (modules under `src/cli`).
  2. Reads HTML from stdin (module `src/stdio`).
  3. Either applies a schema (`src/schema`) or performs selector-driven extraction using `node-html-parser` bindings.
  4. Writes JSON to stdout; errors are printed to stderr and the process exits non-zero.
- Schema system:
  - `src/schema` contains schema loaders and `v1`/`v2` helpers. Schema can be passed inline (`--schema`) or as a file (`--schemaPath`). The loader validates JSON and field types and returns structured rows.
- Bindings & utilities:
  - `src/bindings` holds JS interop for `node-html-parser`, process/json helpers and other Node interop.
- Build output:
  - Bundled artifact is `dist/main.js` (produced by rolldown). The package `bin` field points to `src/Main.res.mjs` for CLI execution in development.

## Key repository-specific conventions

- In-source compilation: `rescript.json` is configured with `in-source: true` and suffix `.res.mjs`. ReScript outputs live alongside sources; treat `.res.mjs` files as build artifacts produced by the compiler.
- CLI validation & error handling:
  - CLI argument parsing occurs in `src/cli` (see `ParseCli.res` for validation rules and custom error types).
  - Errors are surfaced via `Console.error` and `NodeJsBinding.Process.exit(1)`. Scripts and automation should check the CLI exit code.
- Schema format conventions (documented in README & enforced by `Schema`):
  - Top-level `fields` map: each field must include `selector` and `type` (text|attribute|html|number|boolean). Optional `required`, `default`, and `trueValue`/`falseValue` for booleans may be present.
  - `Schema.loadSchema(~isInline=true, raw)` handles inline JSON; `Schema.loadSchema(~isInline=false, path)` reads a file path.
- Extraction modes & defaults:
  - Default extraction is `outerHtml` for single results unless `-e`/`--extract` specifies otherwise.
  - `--mode` controls `single` vs `multiple` results.
- Manual verification: the `examples/` directory contains `sample.html` and schema examples used for quick checks.

## Files and locations Copilot should know to consult first

- `src/Main.res`, `src/cli/*`, `src/schema/*`, `src/bindings/*`, `src/stdio/*`, `README.md`, `examples/`.

## Other AI assistant/agent config files

- None detected (no CLAUDE.md, .cursorrules, AGENTS.md, .windsurfrules, CONVENTIONS.md, .clinerules, etc.).

---

If you'd like, add more coverage for: automated testing guidance, CI steps, or example workflows for packaging/publishing. Let me know what to add or change.