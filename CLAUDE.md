# CLAUDE.md — Agent-assisted workflows for res-scrapy

ReScript CLI for HTML scraping with schema-driven extraction. This guide gives AI agents everything needed to navigate the repo, run the build, and follow the codebase's conventions without re-discovering them.

## Quick path

```bash
pnpm install
pnpm run res:build      # Compile ReScript → src/**/*.res.mjs
pnpm run res:test       # Run *.res.mjs tests via retest
pnpm run bundle         # Bundle src/Main.res.mjs → dist/main.mjs
node dist/main.mjs --help
```

`prepare` runs `bundle` automatically after install. The CLI is invoked as `res-scrapy` (bin entry).

## Build & Test Commands

| Command | Effect |
|---|---|
| `pnpm run res:build` | Run `rescript` compiler. Output: `src/**/*.res.mjs`. |
| `pnpm run res:dev` | `rescript watch` — incremental compile for development. |
| `pnpm run res:clean` | `rescript clean` — wipe generated `.res.mjs` artifacts. |
| `pnpm run res:test` | `retest ./test/res/*.res.mjs` — run the test suite. |
| `pnpm run res:coverage` | `c8 pnpm run res:test` — coverage via c8. |
| `pnpm run bundle` | `rolldown -c` — bundle `src/Main.res.mjs` → `dist/main.mjs`. |
| `pnpm start` | `node dist/main.mjs` — run the bundled CLI. |
| `pnpm run release:check` | Combined: build + test + bundle + date check. |
| `pnpm run security:audit` | `npm audit --audit-level=high`. |

`rolldown.config.mjs` externalises everything matching `/^node:.*/`, `node-html-parser`, and `@rescript/runtime`.

## Architecture Overview

- **Type**: CLI tool, Node.js ≥ 22 (`engines.node`).
- **Language**: ReScript v12 (`@rescript/runtime` ^12.3.0, `rescript` ^12.3.0).
- **Bundle**: Rolldown 1.1.3 + `rollup-plugin-esbuild` for minification; ESM output with `#!/usr/bin/env node` banner.
- **Entry point**: `src/Main.res` → compiles to `src/Main.res.mjs` → bundled to `dist/main.mjs`.
- **Flow**: `Main.res` parses CLI args (`cli/ParseCli.res`), constructs an `AppContext`, branches on the command (URL fetch via `url/UrlRunner.res`, schema extraction via `schema/SchemaRunner.res` or `schema/v2/SchemaV2.res`, table scraping via `table/TableRunner.res`), and writes structured output.

## Dependency Injection

The codebase uses a hand-rolled DI container in `src/core/AppContext.res` rather than module-level globals.

Why this pattern:
- **Testability** — tests construct an `AppContext` with stub implementations of `Fetcher`, `Document`, `OutputWriter`, etc.
- **Explicit wiring** — every dependency is visible at the call site; no hidden state.
- **Swappable adapters** — `NodeHtmlDocument` (production) vs. test doubles live behind the same interface.

Every CLI command receives its dependencies from a single `AppContext.t`. New modules should accept dependencies as arguments, not as module-level `let` bindings.

## Error Handling

- **`src/core/AppError.res`** — single tagged-variant error type covering CLI parsing, IO, network, parsing, and schema failures.
- **`Result<`a`, `AppError.t>`** propagates recoverable errors throughout the pipeline; never throw inside business logic.
- **`src/core/ExnUtils.res`** — `fullMessage` for unwrapping `Js.Exn.t` errors safely.
- **`src/core/ResultX.res`** — `ResultX.flatMap`, `ResultX.sequence`, and other convenience combinators. Prefer these over hand-rolled `switch` ladders.
- Unrecoverable cases (e.g. malformed CLI) exit with a non-zero code and a human-readable message.

## Key Modules

| Path | Role |
|---|---|
| `src/Main.res` | Entry point — wires CLI parsing to runners. |
| `src/cli/Cli.res` | CLI command definitions and dispatch. |
| `src/cli/ParseCli.res` | Argument parsing into typed config records. |
| `src/core/AppContext.res` | DI container — holds all injectable dependencies. |
| `src/core/AppError.res` | Tagged-variant error type for the whole app. |
| `src/core/ResultX.res` | Result helpers (`flatMap`, `sequence`, etc.). |
| `src/core/ExnUtils.res` | Exception → string helpers. |
| `src/core/Document.res` | DOM abstraction interface. |
| `src/core/NodeHtmlDocument.res` | `node-html-parser` adapter for `Document`. |
| `src/core/OutputWriter.res` | Output sink interface. |
| `src/bindings/NodeHtmlParserBinding.res` | FFI bindings to `node-html-parser`. |
| `src/bindings/NodeJsBinding.res` | FFI bindings to Node.js (`fs`, `url`, `path`, etc.). |
| `src/url/UrlRunner.res` | Orchestrates URL fetch + extract + write. |
| `src/url/Fetcher.res` | HTTP fetch interface. |
| `src/url/UrlOutputWriter.res` | Per-URL output writing. |
| `src/url/FetchStatsManager.res` | Aggregates per-URL fetch statistics. |
| `src/url/Reporter.res` | Reports fetch + extraction summaries. |
| `src/url/TemplateParser.res` | URL template substitution. |
| `src/schema/Schema.res` / `SchemaRunner.res` | V1 schema model + runner. |
| `src/schema/v2/SchemaV2.res` | V2 schema orchestrator. |
| `src/schema/v2/parser/` | Config, options, fields, schemas parsers. |
| `src/schema/v2/extractors/` | Per-field-type extractors (text, attribute, list, table, etc.). |
| `src/schema/v2/executor/` | Execution strategies + zip/row extractors. |
| `src/schema/v2/types/FieldTypes.res` | Field type discriminator. |
| `src/schema/v2/utils/` | Date / string / JSON / number helpers. |
| `src/extraction/ExtractionMode.res` | Single vs multi-mode enum. |
| `src/extraction/SelectorExtractor.res` | CSS selector → value extraction. |
| `src/table/TableExtractor.res` | HTML table → rows. |
| `src/table/TableRunner.res` | Table-scraping command runner. |
| `src/stdio/StdIn.res` | Reading from stdin. |

## Code Style Rules

- **Never throw** in business logic — return `Result<`a`, `AppError.t>`. Reserve exceptions for truly unrecoverable startup failures.
- **Use `ResultX.flatMap`** (and other `ResultX.*` combinators) instead of nested `switch` ladders over `Result`.
- **Open `FieldTypes` locally** — modules that pattern-match on field type variants open `FieldTypes` near the match site; do not add it to module-level `open`.
- **Treat `NodeJsBinding.Iter` as the iterator abstraction** — loop over file/dir entries through `Iter.fold` / `Iter.toArray` rather than reaching for raw `for` loops or callback APIs.
- **`%raw` belongs only in `src/bindings/`** — never use `%raw` outside the FFI layer; expose typed wrappers instead.
- **Prefer `JSON.t`** over `Js.Json.t` for new code — narrow `NodeJsBinding.jsonParse` returns `option<JSON.t>`.
- **Match with named constructors** — avoid `as _` when a name clarifies intent.

## Conventions

- **Source files**: `src/**/*.res` — one module per file, file name matches module name.
- **Tests**: `test/res/*.res` compiled to `.res.mjs` and run via `retest`. Mirror production module paths.
- **Bindings**: anything reaching into JS lives under `src/bindings/` with typed wrappers.
- **Formatting**: rely on `rescript` formatter; do not hand-format.
- **Commits**: Conventional Commits (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`). No AI attribution.
- **Branches**: chained PRs (400-line review budget). Verify with `pnpm run release:check` before opening a PR.
- **Generated artifacts**: never edit `src/**/*.res.mjs` or `dist/**` by hand.
