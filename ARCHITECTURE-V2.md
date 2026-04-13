# Schema v2.0 Architecture

This document defines the folder structure, module responsibilities, and implementation roadmap for the res-scrapy schema v2.0 effort.

## Goals

- Modularity: each field type is a separate extractor module
- Separation of concerns: parsing, validation, extraction, execution
- Backwards compatibility with existing v1 schemas
- Testability: unit tests for every module
- Extensibility: easy to add new field types and plugins
- Performance: sensible defaults and caching strategies

---

## Proposed Folder Structure

```
res-scrapy/
├── src/
│   └── schema/
│       ├── Schema.res                    # Public entrypoint (v2)
│       ├── Schema.resi
│       └── v2/                           # v2.0 implementation
│           ├── SchemaV2.res              # v2 public entrypoint
│           ├── SchemaV2.resi
│           ├── types/                    # Type definitions
│           │   ├── SchemaTypes.res
│           │   ├── FieldTypes.res
│           │   ├── OptionTypes.res
│           │   └── ConfigTypes.res
│           ├── parser/                   # Schema parsing & validation
│           │   ├── SchemaParser.res
│           │   ├── FieldParser.res
│           │   ├── OptionsParser.res
│           │   ├── ConfigParser.res
│           │   └── Validator.res
│           ├── extractors/               # One extractor per field type
│           │   ├── ExtractorRegistry.res
│           │   ├── TextExtractor.res
│           │   ├── AttributeExtractor.res
│           │   ├── HtmlExtractor.res
│           │   ├── NumberExtractor.res     # Phase 1 critical fix
│           │   ├── BooleanExtractor.res    # Phase 1 critical fix
│           │   ├── DateTimeExtractor.res
│           │   ├── UrlExtractor.res
│           │   ├── CountExtractor.res
│           │   ├── JsonExtractor.res
│           │   └── ListExtractor.res
│           ├── executor/                 # Execution engine
│           │   ├── SchemaExecutor.res
│           │   ├── RowExtractor.res       # rowSelector-based extraction
│           │   └── ZipExtractor.res       # legacy zip mode
│           └── utils/                    # Shared helpers
│               ├── StringUtils.res
│               ├── NumberUtils.res
│               ├── DateUtils.res
│               ├── UrlUtils.res
│               └── ErrorUtils.res
├── test/
│   ├── unit/
│   │   └── schema/v2/
│   │       ├── parser/
│   │       ├── extractors/
│   │       └── executor/
│   ├── integration/
│   └── fixtures/
├── examples/
│   ├── schemas/
│   └── html/
├── docs/
│   ├── SCHEMA-SPEC.md
│   ├── SCHEMA-EXAMPLES.md
│   └── IMPLEMENTATION-ROADMAP.md
└── scripts/
    ├── test.sh
    └── validate_schemas.sh
```

---

## Module Responsibilities

- `src/schema/Schema.res` — public entrypoint: provides schema loading and application functions.

- `src/schema/v2/types/*` — ReScript types for schema, fields, options and config. Keep types narrow and composable.

- `src/schema/v2/parser/*` — Parse raw JSON → typed schema. Responsibilities:
  - normalize `fields` (object & array forms)
  - parse per-field options (numberOptions, booleanOptions, etc.)
  - apply global defaults from `config.defaults`
  - validate selectors and option shapes and return informative errors

- `src/schema/v2/extractors/*` — One module per field type that exposes an `extract` function:
  - `extract(htmlElement, field, runtimeConfig) => result<JSON.t, schemaError>`
  - each extractor handles its own parsing policies (e.g., `NumberExtractor` handles `stripNonNumeric`, `pattern`, `precision`)

- `src/schema/v2/executor/*` — Execution engine that applies a parsed `schema` to a DOM `document`:
  - `RowExtractor`: recommended mode — query `rowSelector` and run each field relative to each row
  - `ZipExtractor`: legacy mode — run each field against the full document and zip by index

- `src/schema/v2/utils/*` — shared helpers: string/number/date/url utilities; cache compiled regexes here.

---

## Key Design Decisions

1. Row-based extraction (`rowSelector`) is the default recommended model — far more robust than zip-by-first-field.
2. Field-level options are explicit and opt-in; sensible global defaults live under `config.defaults`.
3. All schemas use v2 implementation; v1 support has been removed.
4. Extractors are pure functions (no side effects) returning `Result` types to simplify error handling.
5. Cache compiled regexes and reuse parsing helpers to reduce overhead on repeated extractions.

---

## Parsing & Validation Flow

1. Raw string → `SchemaParser` uses `NodeJsBinding.jsonParse` to parse JSON.
2. `SchemaParser` reads `version` (if present) to choose v1 or v2 parsing rules.
3. `OptionsParser` parses per-field option objects into typed option records.
4. `Validator` runs structural checks (required keys, unknown types, selector sanity) and returns `schemaError` on failure.

---

## Extractor API (recommended)

Each extractor module implements:

```rescript
let extract: (NodeHtmlParserBinding.htmlElement, field, config) => result<JSON.t, schemaError>
```

Registry maps `fieldType` → extractor function; executor calls registry for each field.

---

## Execution Model

- If `config.rowSelector` is present: run `document.querySelectorAll(rowSelector)` and for each row evaluate field selectors relative to that row.
- Otherwise (legacy): run each field selector against `document` and zip results by the first field's length.
- `config.limit` truncates rows produced by either mode.
- `config.ignoreErrors` controls whether the first schema error aborts extraction or is swallowed in favor of defaults.

---

## Implementation Phases (short)

Phase 1 — Foundation & critical fixes (Week 1):

- Create folder skeleton and types
- Implement `numberOptions.stripNonNumeric`, `numberOptions.pattern`
- Implement `booleanOptions.trueValues` and `presence` mode
- Implement multi-attribute `attributes` + `firstNonEmpty` attrMode

Phase 2 — Parser & executor (Week 1–2):

- Implement `OptionsParser`, `FieldParser`, and `SchemaParser`
- Implement `SchemaExecutor` and `RowExtractor`

Phase 3 — Additional extractors & polish (Week 2–4):

- DateTime, URL, Count, JSON, List extractors
- Global defaults and documentation
- Tests and examples

---

## Testing Strategy

- Unit tests: one test file per module with edge cases and option permutations.
- Integration tests: parse → execute flows using real sample HTML fixtures.
- Regression tests: ensure existing schemas continue to produce identical output.

Example test commands (to add to `scripts/`):

```bash
# Run all tests
npm test

# Run unit tests only
npm run test:unit

# Validate example schemas
./scripts/validate_schemas.sh
```

---

## File Naming Conventions

- Implementation: `ModuleName.res`
- Interface: `ModuleName.resi`
- Tests: `ModuleName_test.res`
- Utilities: `*Utils.res`

---

## Next Steps

1. Create the directory structure (scripts or `mkdir -p`).
2. Add the v2 type skeleton under `src/schema/v2/types` and a minimal `SchemaV2.res` wrapper.
3. Implement Phase 1 extractors and parser pieces, with unit tests.

---

## Summary

This architecture separates parsing, option handling, extraction, and execution into clear modules that are easy to test and extend. It preserves the current implementation for compatibility while providing a clear migration path and a robust, typed foundation for the improvements described in the schema specification.
