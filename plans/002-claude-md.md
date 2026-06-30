# Plan 002: Create CLAUDE.md for agent-assisted workflows

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `8e085f5`, 2026-06-30

## Why this matters

The repo has `.github/copilot-instructions.md` (for Copilot) but no
`CLAUDE.md` for Claude or generic AI agents. Since plans in this set will
be executed by agents, a `CLAUDE.md` gives them build commands, architecture
conventions, and test patterns in one place. This is the single highest-ROI
DX improvement for agent-assisted development.

## Current state

- No `CLAUDE.md` or `AGENTS.md` exists at repo root.
- `.github/copilot-instructions.md` exists but contains inaccuracies (fixed
  in Plan 001 — it claims no tests exist).
- The project is a ReScript CLI (`res-scrapy`) that compiles in-source to
  `.res.mjs` files.
- Key conventions: `AppContext` dependency injection, `Result` monad for
  error handling, `FieldTypeVisitor` pattern in extractors.

## Commands you will need

| Purpose   | Command                          | Expected on success |
|-----------|----------------------------------|---------------------|
| Build     | `pnpm run res:build`             | exit 0              |
| Tests     | `pnpm run res:test`              | all pass            |
| Bundle    | `pnpm run bundle`                | exit 0              |

## Scope

**In scope**:
- `CLAUDE.md` (create at repo root)

**Out of scope**:
- Modifying `.github/copilot-instructions.md` (handled in Plan 001)
- Any source code changes

## Steps

### Step 1: Create CLAUDE.md

Create `CLAUDE.md` at the repo root with the following structure and content.
The content below is the complete file — copy it verbatim, then adjust the
"Key modules" section if any file paths have changed.

```markdown
# CLAUDE.md — res-scrapy

## Build & Test Commands

- Install: `pnpm install`
- Build: `pnpm run res:build` (compiles ReScript in-source to `.res.mjs`)
- Watch: `pnpm run res:dev`
- Test: `pnpm run res:test` (432 tests via rescript-test)
- Coverage: `pnpm run res:coverage` (c8)
- Bundle: `pnpm run bundle` (rolldown → `dist/main.mjs`)
- Full release check: `pnpm run release:check`

## Architecture Overview

res-scrapy is a CLI tool that turns HTML into structured JSON. Built in
ReScript v12, compiled in-source to ES modules.

Entry point: `src/Main.res` → `mainWithContext(AppContext.production)`.
Flow: parse CLI → read stdin or fetch URLs → extract via selector/schema/table
→ write JSON/NDJSON to stdout or file.

### Dependency Injection

All side effects go through `AppContext.appContext` (`src/core/AppContext.res`).
The context has:
- `deps` — injected functions (CLI, FS, serialization, document, schema, fetch, perf)
- `io` — output channels (out/err/warn/exit)

Production wires real Node bindings. Tests inject fakes. **Never call
`Console.log`, `process.exit`, or `NodeJsBinding.*` directly outside
`AppContext.res` and `Main.res`.**

### Error Handling

All errors flow through `AppError.appError` (`src/core/AppError.res`).
Pipeline functions return `result<'ok, 'err>` using `ResultX.flatMap`.
Use `ResultX.mapError` to translate domain errors to `appError`.

### Key Modules

| Module | Responsibility |
|--------|---------------|
| `src/Main.res` | Entry point, CLI dispatch, runtime handlers |
| `src/core/AppContext.res` | DI container (deps + io) |
| `src/core/AppError.res` | Unified error type + mappers |
| `src/core/Document.res` | Document/element abstraction over node-html-parser |
| `src/cli/ParseCli.res` | CLI arg validation (Result-based pipeline) |
| `src/cli/Cli.res` | CLI parsing via `util.parseArgs` |
| `src/schema/v2/` | Schema parser, extractors, executor (Strategy pattern) |
| `src/extraction/SelectorExtractor.res` | Non-schema selector extraction |
| `src/url/Fetcher.res` | Concurrent fetching (semaphore, backoff, retry) |
| `src/url/UrlRunner.res` | URL-mode orchestration |
| `src/table/TableExtractor.res` | Standalone table extraction |
| `src/bindings/NodeJsBinding.res` | Node.js FFI (fs, process, util, JSON) |

### Conventions

- **Source files**: `.res` (source) + `.resi` (interface). `.res.mjs` are
  build artifacts — never edit them. They are gitignored.
- **Tests**: `test/res/Foo_test.res` tests `src/Foo.res`. Use `rescript-test`.
- **Formatting**: `rescript format` (2-space indent).
- **Commits**: conventional commits (`feat:`, `fix:`, `refactor:`, `docs:`).

## Code Style Rules

- Use `ResultX.flatMap` for chaining result-producing operations.
- Use `open FieldTypes` inside schema/v2 modules (types are centralized there).
- Use `NodeJsBinding.Iter` for iteration helpers.
- Extract `%raw` JS interop into `src/bindings/` — never inline raw JS in
  domain modules.
- Pattern: `%raw(...)` blocks go in `bindings/`, typed wrappers go in domain code.
```

### Step 2: Verify the file is accurate

Read back the created file. Cross-check these facts:
- Build command: `pnpm run res:build` (matches `package.json:17`)
- Test command: `pnpm run res:test` (matches `package.json:15`)
- Entry point: `src/Main.res` (matches `rolldown.config.mjs:9`)
- Output: `dist/main.mjs` (matches `rolldown.config.mjs:11`)

**Verify**: `pnpm run res:build` → exit 0 (no compilation errors from the
doc changes — this is just a sanity check that nothing broke).

## Done criteria

- [ ] `CLAUDE.md` exists at repo root
- [ ] Build commands match `package.json` scripts
- [ ] Architecture section accurately describes `AppContext` DI pattern
- [ ] Key modules table lists correct file paths
- [ ] No source files outside `CLAUDE.md` are modified

## STOP conditions

- Any file path referenced in the "Key Modules" table does not exist.
- `pnpm run res:build` fails (shouldn't happen since no source changed).
