# url-mode-pipeline Specification

## Purpose

Defines the data flow contract for URL-mode extraction: from the document
through extraction, row counting, and output routing. The pipeline MUST
preserve structured `JSON.t` end-to-end; no module in the URL-mode path
SHALL serialize then re-parse extraction output.

## Requirements

### Requirement: Extraction Returns Structured JSON

The system MUST return extraction results as `result<JSON.t, string>` from
`UrlRunner.extractFromDocument`. Each `extractionSetup` branch MUST
produce a `JSON.t` value that round-trips losslessly through
`JSON.t => string => JSON.t`.

#### Scenario: Schema setup returns JSON.t

- GIVEN a `SchemaSetup` with a valid schema
- WHEN `extractFromDocument` succeeds
- THEN it returns `Ok(json)` where `json: JSON.t`
- AND the result equals the value produced by `applySchema` (no intermediate stringify)

#### Scenario: Table setup returns JSON.t array

- GIVEN a `TableSetup` with rows `[{a: "1"}, {a: "2"}]`
- WHEN `extractFromDocument` succeeds
- THEN it returns `Ok(JSON.Encode.array([JSON.Encode.object([("a", JSON.Encode.string("1"))]), ...]))`

#### Scenario: Selector setup returns JSON.t array of strings

- GIVEN a `SelectorSetup` with selected elements `["foo", "bar"]`
- WHEN `extractFromDocument` succeeds
- THEN it returns `Ok(JSON.Encode.array([JSON.Encode.string("foo"), JSON.Encode.string("bar")]))`

### Requirement: processOne Does Not Re-Parse

The `UrlRunner.processOne` function MUST NOT call
`NodeJsBinding.jsonParse` on extraction output. The JSON.t returned by
`extractFromDocument` MUST be passed directly to row counting and to
`routeOutput`.

#### Scenario: No parse step in processOne

- GIVEN any successful extraction
- WHEN `processOne` routes the result
- THEN no `jsonParse` call exists between extraction and routing

#### Scenario: Nested objects preserved

- GIVEN an extraction result `JSON.Object([("nested", JSON.Object([("k", JSON.Encode.string("v"))]))])`
- WHEN routed through `processOne`
- THEN the same JSON.t reaches `routeOutput` (structural equality)

#### Scenario: Nulls preserved

- GIVEN an extraction result containing `JSON.Encode.null`
- WHEN routed through `processOne`
- THEN the null is passed through unchanged (not converted to empty string)

### Requirement: Row Counting Operates on JSON.t

The `countRows` helper MUST inspect the `JSON.t` directly, returning
`Array.length` for `JSON.Array` and `1` otherwise. The count SHALL be
derived without serializing the value.

#### Scenario: Array row count

- GIVEN `JSON.Array([a, b, c])`
- WHEN `countRows` is called
- THEN it returns `3`

#### Scenario: Bare-object row count

- GIVEN `JSON.Object([("k", JSON.Encode.string("v"))])`
- WHEN `countRows` is called
- THEN it returns `1`

### Requirement: Failed Parse Path Removed

The `UrlRunner.processOne` function MUST NOT record a
`"Failed to parse extraction result"` failure. Extraction either returns
JSON.t or an error string; no intermediate parse failure is reachable.

#### Scenario: No "Failed to parse" failure recorded

- GIVEN an extraction that succeeds with valid JSON.t
- WHEN `processOne` completes
- THEN `FetchStatsManager.recordFailure` is NOT called with reason `"Failed to parse extraction result"`
