# Refactoring Plan: Reducing Coupling in res-scrapy

## Overview

This document outlines the step-by-step refactoring plan to reduce coupling in the res-scrapy HTML scraper using functional programming principles adapted for ReScript.

## Phase 1: Interface Files (.resi)

### Goal
Establish clear module boundaries by creating interface files that hide implementation details.

### Tasks

#### 1.1 Create Main.resi
```rescript
/**
  * Main entry point for the res-scrapy CLI.
  */

/** The main entry point function. */
let main: unit => promise<unit>
```

#### 1.2 Create Cli.resi
```rescript
/**
  * CLI argument parsing module.
  */

/** Parses command line arguments and returns the values. */
let parse: unit => NodeJsBinding.Util.cliValues

/** Displays help message and exits. */
let showHelp: unit => unit
```

#### 1.3 Create NodeHtmlParserBinding.resi
```rescript
/**
  * HTML parser binding interface.
  */

/** Abstract type for HTML elements */
type htmlElement

/** Parses an HTML string into a document node. */
let parse: string => htmlElement

/** Returns all descendants matching selector. */
let querySelectorAll: (htmlElement, string) => array<htmlElement>

/** Returns first descendant matching selector. */
let querySelector: (htmlElement, string) => Nullable.t<htmlElement>

/** Returns attribute value or null. */
let getAttribute: (htmlElement, string) => Nullable.t<string>

/** Accessors */
let textContent: htmlElement => string
let innerHTML: htmlElement => string
let outerHTML: htmlElement => string
let tagName: htmlElement => string
```

#### 1.4 Create TableExtractor.resi
```rescript
/**
  * Table extraction module.
  */

/** Extracts a table as an array of row objects. */
let extract: (
  NodeHtmlParserBinding.htmlElement,
  string,
) => result<array<dict<string>>, string>
```

### Success Criteria
- All core modules have .resi files
- Implementation details are hidden
- Tests still pass

---

## Phase 6: Error Handling Unification

### Goal
Create a unified error type and Result composition helpers.

### Tasks

#### 6.1 Create AppError.res
```rescript
/** Unified application error type. */
type appError =
  | CliError(string)
  | InputError(string)
  | ParseError(string)
  | SchemaError(string)
  | ExtractionError(string)
  | FileError(string)

/** Map StdIn errors to appError. */
let mapStdInError: StdIn.stdInError => appError

/** Map ParseCli errors to appError. */
let mapParseError: ParseCli.parseError => appError

/** Map Schema errors to appError. */
let mapSchemaError: FieldTypes.schemaError => appError

/** Convert appError to user-friendly message. */
let toMessage: appError => string
```

#### 6.2 Create ResultX.res
```rescript
/** Result composition helpers. */

/** Maps the error type of a result. */
let mapError: (result<'a, 'b>, 'b => 'c) => result<'a, 'c>

/** Flattens a nested result. */
let flatten: result<result<'a, 'b>, 'b> => result<'a, 'b>

/** Chains result operations. */
let flatMap: (result<'a, 'b>, 'a => result<'c, 'b>) => result<'c, 'b>

/** Maps both sides of a result. */
let bimap: (result<'a, 'b>, 'a => 'c, 'b => 'd) => result<'c, 'd>
```

#### 6.3 Add Tests
- Create test/res/AppError_test.res
- Create test/res/ResultX_test.res

---

## Phase 2: Strategy Pattern (Functor-Based)

### Goal
Make extraction strategies composable using ReScript functors.

### Tasks

#### 2.1 Create ExtractionStrategy.res
```rescript
/** Strategy module signature. */
module type Strategy = {
  type input
  type output
  type config
  
  let name: string
  let canHandle: config => bool
  let execute: (input, config) => result<output, FieldTypes.schemaError>
}

/** Strategy registry using first-class modules. */
type strategyImpl =
  | Strategy(module Strategy with type input = 'a 
                            and type output = 'b 
                            and type config = 'c)

/** Registry of available strategies. */
let registry: array<strategyImpl>

/** Select appropriate strategy for config. */
let select: (FieldTypes.schemaConfig, array<strategyImpl>) => option<strategyImpl>
```

#### 2.2 Refactor RowExtractor as Strategy
```rescript
module RowStrategy: ExtractionStrategy.Strategy with
  type input = NodeHtmlParserBinding.htmlElement and
  type output = JSON.t and
  type config = FieldTypes.schema
```

#### 2.3 Refactor ZipExtractor as Strategy
```rescript
module ZipStrategy: ExtractionStrategy.Strategy with
  type input = NodeHtmlParserBinding.htmlElement and
  type output = JSON.t and
  type config = FieldTypes.schema
```

#### 2.4 Update SchemaExecutor
```rescript
let applySchema = (document, schema) => {
  open ExtractionStrategy
  let strategies = [module RowStrategy, module ZipStrategy]
  switch select(schema.config, strategies) {
  | None => Error(ExtractionError("No strategy available"))
  | Some(Strategy(strategy)) => 
    let module S = unpack(strategy)
    S.execute(document, schema)
  }
}
```

### Success Criteria
- Strategies are modular and testable
- New strategies can be added without modifying existing code
- Tests pass

---

## Phase 3: Extractor Registry (Functor-Based)

### Goal
Replace the "big switch" with a type-safe functor-based registry.

### Tasks

#### 3.1 Create Extractor.res (Module Signature)
```rescript
/** Extractor module signature. */
module type Extractor = {
  type input
  type output
  type options
  
  let fieldType: FieldTypes.fieldType
  let extract: (input, option<options>) => option<output>
  let toJson: output => JSON.t
}
```

#### 3.2 Create ExtractorRegistry.res
```rescript
/** Type-safe extractor registry. */

type extractorImpl =
  | Extractor(module Extractor with type input = 'a 
                              and type output = 'b 
                              and type options = 'c)

/** Registry of all extractors. */
let registry: array<extractorImpl>

/** Find extractor for field type. */
let find: FieldTypes.fieldType => option<extractorImpl>

/** Extract value using appropriate extractor. */
let extract: (
  NodeHtmlParserBinding.htmlElement,
  FieldTypes.fieldType,
  option<FieldTypes.schemaDefaults>,
  bool
) => result<JSON.t, FieldTypes.schemaError>
```

#### 3.3 Convert Each Extractor to Module
- TextExtractor → module TextExtractor : Extractor
- NumberExtractor → module NumberExtractor : Extractor
- BooleanExtractor → module BooleanExtractor : Extractor
- And so on for all extractors...

#### 3.4 Add Tests
- Create test/res/ExtractorRegistryFunctor_test.res
- Test each extractor module

---

## Phase 5: Document Abstraction

### Goal
Abstract HTML parser for testability.

### Tasks

#### 5.1 Create Document.res
```rescript
/** Abstract document operations. */

type document
type element

type operations = {
  parse: string => document,
  querySelector: (document, string) => option<element>,
  querySelectorAll: (document, string) => array<element>,
  getAttribute: (element, string) => option<string>,
  textContent: element => string,
  innerHTML: element => string,
  outerHTML: element => string,
}
```

#### 5.2 Create NodeHtmlParser.res
```rescript
/** Node-html-parser implementation. */

let operations: Document.operations
```

#### 5.3 Update Extractors
Update all extractors to accept Document.operations as parameter.

---

## Phase 4: Dependency Injection

### Goal
Make Main.res testable with explicit dependencies.

### Tasks

#### 4.1 Create AppContext.res
```rescript
/** Application dependency context. */

type extractionDeps = {
  parseCli: unit => NodeJsBinding.Util.cliValues,
  validateArgs: NodeJsBinding.Util.cliValues => result<ParseCli.parseOptions, ParseCli.parseError>,
  readStdin: unit => promise<result<string, StdIn.stdInError>>,
  parseHtml: string => NodeHtmlParserBinding.htmlElement,
  extractTable: (NodeHtmlParserBinding.htmlElement, string) => result<array<dict<string>>, string>,
  loadSchema: (~isInline: bool, string) => result<schema, FieldTypes.schemaError>,
  applySchema: (NodeHtmlParserBinding.htmlElement, schema) => result<JSON.t, FieldTypes.schemaError>,
  outputWriter: string => unit,
  errorHandler: string => unit,
  exit: int => unit,
}

/** Production dependencies. */
let production: extractionDeps

/** Create test dependencies with mocks. */
let createTestContext: (
  ~parseCli: unit => NodeJsBinding.Util.cliValues=?,
  ~validateArgs: NodeJsBinding.Util.cliValues => result<ParseCli.parseOptions, ParseCli.parseError>=?,
  ~readStdin: unit => promise<result<string, StdIn.stdInError>>=?,
  ~parseHtml: string => NodeHtmlParserBinding.htmlElement=?,
  ~extractTable: (NodeHtmlParserBinding.htmlElement, string) => result<array<dict<string>>, string>=?,
  ~loadSchema: (~isInline: bool, string) => result<schema, FieldTypes.schemaError>=?,
  ~applySchema: (NodeHtmlParserBinding.htmlElement, schema) => result<JSON.t, FieldTypes.schemaError>=?,
  ~outputWriter: string => unit=?,
  ~errorHandler: string => unit=?,
  ~exit: int => unit=?,
  unit
) => extractionDeps
```

#### 4.2 Refactor Main.res
```rescript
let mainWithContext = async (ctx: AppContext.extractionDeps) => {
  // Use ctx for all operations
}

let main = () => mainWithContext(AppContext.production)
```

#### 4.3 Add Tests
- Create test/res/MainContext_test.res
- Test with mocked context

---

## Phase 7: Unified Extraction Modes

### Goal
Consolidate table, schema, and selector extraction.

### Tasks

#### 7.1 Create ExtractionMode.res
```rescript
/** Unified extraction modes. */

type extractionMode =
  | TableMode({selector: string})
  | SchemaMode({source: ParseCli.schemaSource})
  | SelectorMode({
      selector: string,
      extract: ParseCli.extractMode,
      mode: ParseCli.mode,
    })

type extractionHandler = {
  supports: ParseCli.parseOptions => option<extractionMode>,
  execute: (NodeHtmlParserBinding.htmlElement, extractionMode) => result<JSON.t, AppError.appError>,
}
```

#### 7.2 Create Handler Modules
- TableHandler
- SchemaHandler
- SelectorHandler

#### 7.3 Create Dispatcher
```rescript
let dispatch = (
  handlers: array<extractionHandler>,
  options: ParseCli.parseOptions
) => option<(extractionMode, extractionHandler)>
```

---

## Cleanup: Remove SchemaV1

### Tasks
- Remove src/schema/v1/SchemaV1.res
- Remove src/schema/v1/SchemaV1.resi (if exists)
- Update any references
- Ensure tests still pass

---

## Testing Strategy

Each phase should include:

1. **Unit Tests**: Test pure functions
2. **Module Tests**: Test module interfaces
3. **Integration Tests**: Test component interactions
4. **E2E Tests**: Test full pipeline

### Test Structure
```
test/res/
├── Phase1_Interface_test.res
├── Phase6_AppError_test.res
├── Phase6_ResultX_test.res
├── Phase2_Strategy_test.res
├── Phase3_ExtractorFunctor_test.res
├── Phase4_Context_test.res
├── Phase5_Document_test.res
└── Phase7_ExtractionMode_test.res
```

---

## Implementation Order

1. Phase 1 (Interfaces) - Foundation
2. Phase 6 (Errors) - Enables consistent error handling
3. Phase 2 (Strategies) - Major architectural improvement
4. Phase 3 (Extractors) - Eliminates big switch
5. Phase 5 (Document) - Testability improvement
6. Phase 4 (Context) - Main.res refactor
7. Phase 7 (Unified Modes) - Final consolidation
8. Cleanup (Remove V1)

---

## Success Metrics

| Metric | Before | After |
|--------|--------|-------|
| Main.res lines | 150 | ~40 |
| Direct dependencies in Main | 6+ | 1 (AppContext) |
| Extractor registry size | 250+ lines | ~50 lines |
| Test coverage | Current | +20% |
| New field type addition | 2+ files | 1 file |

---

## Notes

- Use ReScript module functors for type-safe abstraction
- Maintain backward compatibility with existing tests
- Each phase must have passing tests before proceeding
- Document all public APIs in .resi files
