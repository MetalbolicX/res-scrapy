# Implementation Roadmap: Schema v1.0 → v2.0

This document outlines the path from the current implementation to the full v2.0 specification.

## Current State (v1.0)

### Supported Features

**Field Types:**

- ✅ `text` - extract `.textContent`
- ✅ `attribute` - extract single attribute value
- ✅ `html` - extract `.innerHTML`
- ✅ `number` - parse with `parseFloat` (returns `null` on `NaN`)
- ✅ `boolean` - check if text equals `"true"` (case-insensitive)

**Field Options:**

- ✅ `selector` - CSS selector
- ✅ `required` - mark field as required
- ✅ `default` - fallback string value
- ✅ `attribute` - for `type: "attribute"`, which attribute to extract

**Global Config:**

- ✅ `ignoreErrors` - suppress field extraction errors
- ✅ `limit` - max rows to extract
- ✅ `name` - schema name (optional)
- ✅ `description` - schema description (optional)

**Field Definition Formats:**

- ✅ Object format: `{"fields": {"name": {...}}}`
- ✅ Array format: `{"fields": [{"name": "...", ...}]}`

**Extraction Model:**

- ✅ Zip-by-first-field: Each field's selector runs against document root, results zipped by index

### Current Limitations

**Number Parsing:**

```javascript
// Current behavior
parseFloat("$29.99"); // → NaN → null ❌
parseFloat("1,234.56"); // → 1 (stops at comma) ❌
parseFloat("25%"); // → 25 ✅ (works by accident)
```

**Boolean Parsing:**

```javascript
// Current behavior
"true".toLowerCase() === "true"; // → true ✅
"In Stock".toLowerCase() === "true"; // → false ❌
"yes".toLowerCase() === "true"; // → false ❌
```

**Attribute Extraction:**

```javascript
// Current: only single attribute
{"type": "attribute", "attribute": "href"}  // ✅

// Fallback not supported
{"type": "attribute", "attributes": ["data-src", "src"]}  // ❌
```

**HTML Extraction:**

```javascript
// Current: always innerHTML
element.innerHTML  // ✅

// No option for outerHTML
{"type": "html", "htmlOptions": {"mode": "outer"}}  // ❌
```

---

## Implementation Phases

### Phase 1: Critical Fixes (High Priority)

**Goal:** Fix the issues mentioned in the user's report.

#### 1.1 Enhanced Number Parsing

**Changes needed in `Schema.res`:**

```rescript
// Current implementation
let extractValue: (NodeHtmlParserBinding.htmlElement, fieldType) => JSON.t = (el, fieldType) =>
  switch fieldType {
  | Number => {
      let n = el.textContent->String.trim->toFloat
      isNaN(n) ? JSON.Encode.null : n->JSON.Encode.float
    }
  // ...
  }

// Proposed: Add number options
type numberOptions = {
  stripNonNumeric?: bool,           // Default: true
  pattern?: string,                 // Regex to extract number
  thousandsSeparator?: string,      // Default: ","
  decimalSeparator?: string,        // Default: "."
  onError?: string,                 // "null" | "text" | "default"
}

type fieldType =
  | Text
  | Attribute(string)
  | Html
  | Number(option<numberOptions>)   // Add options parameter
  | Boolean(option<booleanOptions>) // Add options parameter

// Helper function to strip non-numeric characters
let stripNonNumeric: string => string = str => {
  // Remove everything except digits, -, .
  str->Js.String2.replaceByRe(%re("/[^0-9.\-]+/g"), "")
}

// Enhanced number extraction
let extractNumber: (string, option<numberOptions>) => JSON.t = (text, options) => {
  let opts = options->Option.getOr({
    stripNonNumeric: Some(true),
    pattern: None,
    thousandsSeparator: Some(","),
    decimalSeparator: Some("."),
    onError: Some("null")
  })

  let cleaned = switch opts.stripNonNumeric {
  | Some(true) => stripNonNumeric(text)
  | _ => text
  }

  // Apply pattern if provided
  let value = switch opts.pattern {
  | Some(pattern) => {
      // Extract using regex capture group
      // Implementation depends on regex binding
      cleaned
    }
  | None => cleaned
  }

  // Replace thousand separators
  let normalized = switch opts.thousandsSeparator {
  | Some(sep) => value->Js.String2.replaceByRe(Js.Re.fromString(sep), "")
  | None => value
  }

  let n = toFloat(normalized)

  if isNaN(n) {
    switch opts.onError {
    | Some("text") => text->JSON.Encode.string
    | Some("null") | _ => JSON.Encode.null
    }
  } else {
    n->JSON.Encode.float
  }
}
```

**Schema changes:**

```json
{
  "price": {
    "selector": ".price",
    "type": "number",
    "numberOptions": {
      "stripNonNumeric": true,
      "onError": "null"
    }
  }
}
```

#### 1.2 Enhanced Boolean Parsing

**Changes needed in `Schema.res`:**

```rescript
type booleanMode = Mapping | Presence | Attribute

type booleanOptions = {
  mode?: booleanMode,              // Default: Mapping
  trueValues?: array<string>,      // Default: ["true", "yes", "1"]
  falseValues?: array<string>,     // Default: ["false", "no", "0"]
  attribute?: string,              // For Attribute mode
  onUnknown?: string,              // "false" | "null"
}

let extractBoolean: (
  NodeHtmlParserBinding.htmlElement,
  option<booleanOptions>,
  string  // selector (for presence mode)
) => JSON.t = (el, options, selector) => {
  let opts = options->Option.getOr({
    mode: Some(Mapping),
    trueValues: Some(["true", "yes", "1"]),
    falseValues: Some(["false", "no", "0"]),
    attribute: None,
    onUnknown: Some("false")
  })

  let result = switch opts.mode {
  | Some(Presence) => {
      // Return true if element exists (would need document context)
      true
    }
  | Some(Attribute) => {
      switch opts.attribute {
      | Some(attr) => {
          let attrValue = el->NodeHtmlParserBinding.getAttribute(attr)
          switch attrValue->Nullable.toOption {
          | None => false
          | Some("") => false
          | Some("false") => false
          | Some(_) => true
          }
        }
      | None => false
      }
    }
  | Some(Mapping) | None => {
      let text = el.textContent->String.trim->String.toLowerCase

      let trueVals = opts.trueValues->Option.getOr(["true", "yes", "1"])
      let falseVals = opts.falseValues->Option.getOr(["false", "no", "0"])

      if trueVals->Array.some(v => v->String.toLowerCase == text) {
        true
      } else if falseVals->Array.some(v => v->String.toLowerCase == text) {
        false
      } else {
        // Unknown value
        switch opts.onUnknown {
        | Some("null") => false  // Would need to return option<bool>
        | _ => false
        }
      }
    }
  }

  result->JSON.Encode.bool
}
```

**Schema changes:**

```json
{
  "inStock": {
    "selector": ".stock-status",
    "type": "boolean",
    "booleanOptions": {
      "mode": "mapping",
      "trueValues": ["in stock", "available", "yes"],
      "falseValues": ["out of stock", "unavailable", "no"]
    }
  }
}
```

#### 1.3 Multi-Attribute Support

**Changes needed in `Schema.res`:**

```rescript
type attrMode = First | FirstNonEmpty | All | Join

type fieldType =
  | Text
  | Attribute({
      names: array<string>,        // Changed from single string
      mode: attrMode,
      join?: string,
    })
  | Html
  | Number(option<numberOptions>)
  | Boolean(option<booleanOptions>)

let extractAttribute: (
  NodeHtmlParserBinding.htmlElement,
  array<string>,  // attribute names
  attrMode,
  option<string>  // join separator
) => JSON.t = (el, names, mode, joinSep) => {
  switch mode {
  | FirstNonEmpty => {
      let found = names->Array.reduce(None, (acc, name) => {
        switch acc {
        | Some(_) => acc  // Already found
        | None => {
            let value = el->NodeHtmlParserBinding.getAttribute(name)
            switch value->Nullable.toOption {
            | None | Some("") => None
            | Some(v) => Some(v)
            }
          }
        }
      })
      switch found {
      | None => JSON.Encode.null
      | Some(v) => v->JSON.Encode.string
      }
    }
  | First => {
      let value = names->Array.get(0)->Option.flatMap(name =>
        el->NodeHtmlParserBinding.getAttribute(name)->Nullable.toOption
      )
      switch value {
      | None => JSON.Encode.null
      | Some(v) => v->JSON.Encode.string
      }
    }
  | All => {
      let obj = names->Array.reduce(Dict.make(), (dict, name) => {
        let value = el->NodeHtmlParserBinding.getAttribute(name)
        switch value->Nullable.toOption {
        | Some(v) => dict->Dict.set(name, v->JSON.Encode.string)
        | None => dict->Dict.set(name, JSON.Encode.null)
        }
        dict
      })
      JSON.Encode.object(obj)
    }
  | Join => {
      let values = names->Array.reduce([], (arr, name) => {
        let value = el->NodeHtmlParserBinding.getAttribute(name)
        switch value->Nullable.toOption {
        | None | Some("") => arr
        | Some(v) => {
            arr->Array.push(v)
            arr
          }
        }
      })
      let joined = values->Array.join(joinSep->Option.getOr(", "))
      joined->JSON.Encode.string
    }
  }
}
```

**Schema changes:**

```json
{
  "imageUrl": {
    "selector": "img",
    "type": "attribute",
    "attributes": ["data-lazy-src", "data-src", "src"],
    "attrMode": "firstNonEmpty"
  }
}
```

**Parsing changes:**

```rescript
let parseFieldType: (string, {..}) => result<fieldType, schemaError> = (fieldName, rawField) => {
  let typeStr: option<string> = dictGet(rawField, "type")
  switch typeStr {
  | None | Some("text") => Ok(Text)
  | Some("html") => Ok(Html)
  | Some("number") => {
      let opts: option<{..}> = dictGet(rawField, "numberOptions")
      // Parse numberOptions...
      Ok(Number(parsedOpts))
    }
  | Some("boolean") => {
      let opts: option<{..}> = dictGet(rawField, "booleanOptions")
      // Parse booleanOptions...
      Ok(Boolean(parsedOpts))
    }
  | Some("attribute") => {
      // Support both old and new syntax
      let singleAttr: option<string> = dictGet(rawField, "attribute")
      let multiAttrs: option<array<string>> = dictGet(rawField, "attributes")

      let names = switch (singleAttr, multiAttrs) {
      | (_, Some(arr)) => arr
      | (Some(single), None) => [single]
      | (None, None) => {
          return Error(AttributeMissingKey(
            `Field "${fieldName}" has type "attribute" but is missing "attribute" or "attributes" key`
          ))
        }
      }

      let modeStr: option<string> = dictGet(rawField, "attrMode")
      let mode = switch modeStr {
      | Some("first") => First
      | Some("firstNonEmpty") | None => FirstNonEmpty
      | Some("all") => All
      | Some("join") => Join
      | Some(other) => FirstNonEmpty  // Default
      }

      let join: option<string> = dictGet(rawField, "attrJoin")

      Ok(Attribute({names, mode, ?join}))
    }
  | Some(other) => Error(InvalidFieldType({field: fieldName, got: other}))
  }
}
```

---

### Phase 2: New Field Types (Medium Priority)

#### 2.1 DateTime Type

**New types needed:**

```rescript
type dateFormat = ISO | Epoch | EpochMillis | Custom(string)

type dateOptions = {
  formats?: array<dateFormat>,
  timezone?: string,
  output?: dateFormat,
  strict?: bool,
  source?: string,  // "text" | "attribute"
  attribute?: string,
}

type fieldType =
  | Text
  | Attribute({...})
  | Html
  | Number(option<numberOptions>)
  | Boolean(option<booleanOptions>)
  | DateTime(option<dateOptions>)  // New type
```

**Implementation:**

- Requires date parsing library (e.g., `@rescript/js` Date or external library)
- Parse multiple formats in order
- Handle timezone conversion
- Output in specified format

#### 2.2 URL Type

```rescript
type urlOptions = {
  base?: string,
  resolve?: bool,
  validate?: bool,
  protocol?: string,
  stripQuery?: bool,
  stripHash?: bool,
  attribute?: string,
}

type fieldType =
  | ...
  | URL(option<urlOptions>)  // New type
```

**Implementation:**

- Use Node.js `URL` API for parsing/resolution
- Validate URL format
- Resolve relative URLs against base
- Strip query/hash if requested

#### 2.3 Count Type

```rescript
type countOptions = {
  min?: int,
  max?: int,
}

type fieldType =
  | ...
  | Count(option<countOptions>)  // New type
```

**Implementation:**

- Simple: return `querySelectorAll` length
- Validate against min/max if provided

#### 2.4 JSON Type

```rescript
type jsonOptions = {
  source?: string,  // "text" | "attribute"
  attribute?: string,
  path?: string,    // JSONPath selector
  validate?: bool,
  onError?: string,
}

type fieldType =
  | ...
  | JSON(option<jsonOptions>)  // New type
```

**Implementation:**

- Parse JSON from text or attribute
- Optional JSONPath extraction
- Error handling policies

#### 2.5 List Type

```rescript
type listItemType = ListText | ListHtml | ListAttribute(string) | ListURL

type listOptions = {
  itemType: listItemType,
  unique?: bool,
  filter?: string,  // Regex pattern
  limit?: int,
  join?: string,
}

type fieldType =
  | ...
  | List(option<listOptions>)  // New type
```

**Implementation:**

- Collect multiple matches
- Extract each according to itemType
- Deduplicate if unique=true
- Join if join provided, else return array

---

### Phase 3: Extraction Model Enhancement (High Priority)

#### 3.1 Row Selector

**Changes needed:**

Currently:

```rescript
let applySchema: (NodeHtmlParserBinding.htmlElement, schema) => result<JSON.t, schemaError> = (
  document,
  schema,
) => {
  // Collect per-field element lists (all queries run from document root)
  let fieldLists: array<(string, schemaField, array<...>)> =
    schema.fields->Array.map(((name, field)) => {
      (name, field, document->NodeHtmlParserBinding.querySelectorAll(field.selector))
    })

  // Row count driven by first field
  let rowCount = switch fieldLists->Array.get(0) {
  | None => 0
  | Some((_, _, els)) => els->Array.length
  }
  // ... zip by index
}
```

Proposed:

```rescript
type schema = {
  name?: string,
  description?: string,
  fields: array<(string, schemaField)>,
  config: schemaConfig,
  rowSelector?: string,  // NEW
}

let applySchema: (NodeHtmlParserBinding.htmlElement, schema) => result<JSON.t, schemaError> = (
  document,
  schema,
) => {
  switch schema.rowSelector {
  | None => {
      // Legacy behavior: zip by first field
      applySchemaZipMode(document, schema)
    }
  | Some(rowSel) => {
      // New behavior: row-relative extraction
      let rows = document->NodeHtmlParserBinding.querySelectorAll(rowSel)

      let limitedRows = switch schema.config.limit {
      | 0 => rows
      | n => rows->Array.slice(~start=0, ~end=n)
      }

      let results = limitedRows->Array.map(row => {
        // Extract fields relative to this row
        let fieldPairs = schema.fields->Array.map(((name, field)) => {
          let el = switch field.multiple {
          | Some(true) =>
              row->NodeHtmlParserBinding.querySelectorAll(field.selector)
          | _ =>
              row->NodeHtmlParserBinding.querySelector(field.selector)
                ->Nullable.toOption
          }

          let value = switch el {
          | None =>
              if field.required && !schema.config.ignoreErrors {
                Error(RequiredFieldMissing({...}))
              } else {
                Ok(field.default->Option.getOr(JSON.Encode.null))
              }
          | Some(element) => Ok(extractValue(element, field.fieldType))
          }

          value->Result.map(v => (name, v))
        })

        // Collect field results into object
        // ...
      })

      Ok(JSON.Encode.array(results))
    }
  }
}
```

**Schema change:**

```json
{
  "config": {
    "rowSelector": ".product-card"
  },
  "fields": {
    "name": { "selector": "h2", "type": "text" },
    "price": { "selector": ".price", "type": "number" }
  }
}
```

---

### Phase 4: Text & HTML Options (Low Priority)

#### 4.1 Text Options

```rescript
type textOptions = {
  trim?: bool,
  normalizeWhitespace?: bool,
  lowercase?: bool,
  uppercase?: bool,
  pattern?: string,
  join?: string,
}

type fieldType =
  | Text(option<textOptions>)  // Add options
  | ...
```

#### 4.2 HTML Options

```rescript
type htmlMode = Inner | Outer

type htmlOptions = {
  mode?: htmlMode,
  stripScripts?: bool,
  stripStyles?: bool,
}

type fieldType =
  | ...
  | Html(option<htmlOptions>)  // Add options
```

---

### Phase 5: Global Defaults (Low Priority)

```rescript
type globalDefaults = {
  text?: textOptions,
  number?: numberOptions,
  boolean?: booleanOptions,
  datetime?: dateOptions,
  url?: urlOptions,
}

type schemaConfig = {
  ignoreErrors: bool,
  limit: int,
  rowSelector?: string,
  defaults?: globalDefaults,  // NEW
}
```

**Parsing:**

- Parse global defaults from `config.defaults`
- Merge with field-level options (field-level takes precedence)

---

## Testing Strategy

### Unit Tests

```javascript
// test/Schema_test.res
describe("Number parsing", () => {
  test("strips currency symbols", () => {
    let result = extractNumber("$29.99", Some({
      stripNonNumeric: Some(true),
      ...defaultNumberOptions
    }))
    expect(result)->toEqual(29.99)
  })

  test("handles thousand separators", () => {
    let result = extractNumber("1,234.56", Some({
      stripNonNumeric: Some(true),
      thousandsSeparator: Some(","),
      ...defaultNumberOptions
    }))
    expect(result)->toEqual(1234.56)
  })
})

describe("Boolean parsing", () => {
  test("maps custom true values", () => {
    let result = extractBoolean(mockElement("In Stock"), Some({
      trueValues: Some(["in stock", "available"]),
      ...defaultBooleanOptions
    }))
    expect(result)->toEqual(true)
  })
})
```

### Integration Tests

```bash
# Test currency parsing
echo '<div class="price">$29.99</div>' | \
  node src/Main.res.mjs --schema test/schemas/currency.json

# Test boolean mapping
echo '<div class="stock">In Stock</div>' | \
  node src/Main.res.mjs --schema test/schemas/boolean-mapping.json

# Test multi-attribute fallback
echo '<img data-src="lazy.jpg" src="eager.jpg">' | \
  node src/Main.res.mjs --schema test/schemas/multi-attr.json
```

---

## Migration Guide for Users

### v1.0 → v2.0 Breaking Changes

1. **Number type default behavior change:**

   ```json
   // v1.0: parseFloat("$29.99") → NaN → null
   // v2.0: stripNonNumeric: true by default → 29.99
   ```

   **Migration:** Explicitly disable if you don't want stripping:

   ```json
   {
     "type": "number",
     "numberOptions": { "stripNonNumeric": false }
   }
   ```

2. **Boolean type behavior change:**

   ```json
   // v1.0: Only "true" → true, everything else → false
   // v2.0: trueValues: ["true", "yes", "1"] by default
   ```

   **Migration:** Use old behavior:

   ```json
   {
     "type": "boolean",
     "booleanOptions": {
       "trueValues": ["true"],
       "falseValues": []
     }
   }
   ```

3. **Attribute type syntax:**

   ```json
   // v1.0: (still works in v2.0)
   {"type": "attribute", "attribute": "href"}

   // v2.0: (new syntax)
   {"type": "attribute", "attributes": ["href"]}
   ```

---

## Backwards Compatibility

**Support both syntaxes where possible:**

- `attribute` (singular) and `attributes` (plural)
- Default behaviors match v1.0 unless opts provided
- Detect schema version via `"version"` field (optional)

**Version detection:**

```rescript
let parseSchema: string => result<schema, schemaError> = raw => {
  switch NodeJsBinding.jsonParse(raw) {
  | Some(obj) => {
      let version: option<string> = dictGet(obj, "version")
      let useV2Features = switch version {
      | Some("2.0") | Some("2.1") => true
      | _ => false
      }

      // Apply version-specific defaults
      // ...
    }
  }
}
```

---

## Estimated Effort

| Phase     | Description     | Complexity | Est. Time      |
| --------- | --------------- | ---------- | -------------- |
| 1.1       | Number parsing  | Medium     | 2-3 days       |
| 1.2       | Boolean parsing | Medium     | 2-3 days       |
| 1.3       | Multi-attribute | Low        | 1-2 days       |
| 2.1       | DateTime type   | High       | 3-5 days       |
| 2.2       | URL type        | Low        | 1-2 days       |
| 2.3       | Count type      | Low        | 1 day          |
| 2.4       | JSON type       | Medium     | 2-3 days       |
| 2.5       | List type       | Medium     | 2-3 days       |
| 3.1       | Row selector    | High       | 3-4 days       |
| 4.1-4.2   | Text/HTML opts  | Low        | 1-2 days       |
| 5         | Global defaults | Medium     | 2-3 days       |
| **Total** |                 |            | **20-30 days** |

---

## Priority Recommendations

**Immediate (Phase 1):**

- Number parsing with `stripNonNumeric`
- Boolean parsing with `trueValues`/`falseValues`
- Multi-attribute support with `firstNonEmpty`

**Soon after (Phase 3):**

- Row selector (most impactful for user experience)

**Future (Phases 2, 4, 5):**

- Additional field types as needed
- Text/HTML options
- Global defaults

---

## Open Questions

1. **Regex support in ReScript:**
   - Which regex library to use? Built-in `Js.Re` or external?
   - Pattern compilation and caching strategy?

2. **Date parsing:**
   - Use `Js.Date` or external library like `date-fns`?
   - How to handle relative dates ("2 days ago")?

3. **Error handling:**
   - Should `onError: "text"` return original text or JSON string?
   - How to handle multiple errors in `ignoreErrors` mode?

4. **Performance:**
   - Cache compiled regexes?
   - Parallel field extraction possible?

5. **Output formats:**
   - Support CSV, JSONL in addition to JSON?
   - Streaming for large datasets?
