# Schema Specification v2.0

## Overview

This document defines the complete specification for res-scrapy schema files. A schema is a JSON document that describes how to extract structured data from HTML documents.

## Schema Structure

```rescript
{
  name?: string;                    // Optional human-readable schema name
  description?: string;             // Optional schema description
  rowSelector?: string;             // Optional: root selector for row-based extraction
  fields: FieldsDefinition;         // Required: field extraction rules
  config?: GlobalConfig;            // Optional: global extraction settings
}
```

---

## Fields Definition

Fields can be defined in **two formats**:

### Object Format (recommended)

```json
{
  "fields": {
    "fieldName": {
      /* field definition */
    },
    "anotherField": {
      /* field definition */
    }
  }
}
```

### Array Format (legacy support)

```json
{
  "fields": [
    { "name": "fieldName" /* other keys */ },
    { "name": "anotherField" /* other keys */ }
  ]
}
```

---

## Field Definition

Each field has the following base structure:

```rescript
{
  selector: string;                 // Required: CSS selector (relative to rowSelector if set)
  type: FieldType;                  // Required: extraction type
  required?: boolean;               // Default: false
  default?: any;                    // Fallback value when element not found
  multiple?: boolean;               // Default: false - return array of matches
  transform?: TransformOptions;     // Optional: post-extraction transformations
}
```

---

## Field Types

### 1. **Text**

Extract text content from elements.

```rescript
{
  type: "text";
  textOptions?: {
    trim?: boolean;                 // Default: true
    normalizeWhitespace?: boolean;  // Default: false - collapse multiple spaces/newlines
    lowercase?: boolean;            // Default: false
    uppercase?: boolean;            // Default: false
    pattern?: string;               // Regex pattern to extract (capture group 1)
    join?: string;                  // When multiple=true, join array with this separator
  };
}
```

**Example:**

```json
{
  "title": {
    "selector": "h1",
    "type": "text",
    "textOptions": {
      "trim": true,
      "normalizeWhitespace": true
    }
  },
  "tags": {
    "selector": ".tag",
    "type": "text",
    "multiple": true,
    "textOptions": {
      "join": ", "
    }
  }
}
```

**Default behavior:**

- `trim: true`
- Returns `.textContent` of the matched element
- When `multiple=true`, returns array of text values

---

### 2. **Attribute**

Extract attribute values from elements.

```rescript
{
  type: "attribute";
  attribute?: string;               // Single attribute name (legacy)
  attributes?: string[];            // Array of attribute names to try
  attrMode?: "first" | "firstNonEmpty" | "all" | "join";  // Default: "firstNonEmpty"
  attrJoin?: string;                // When attrMode="join", separator to use
}
```

**Modes:**

- `first`: Return first attribute in list (even if empty/null)
- `firstNonEmpty`: Return first non-null, non-empty attribute (default)
- `all`: Return object `{attr1: value1, attr2: value2}`
- `join`: Concatenate all non-empty attributes with `attrJoin` separator

**Example:**

```json
{
  "imageUrl": {
    "selector": "img",
    "type": "attribute",
    "attributes": ["data-src", "src"],
    "attrMode": "firstNonEmpty"
  },
  "allAttrs": {
    "selector": "a",
    "type": "attribute",
    "attributes": ["href", "title", "rel"],
    "attrMode": "all"
  },
  "legacySyntax": {
    "selector": "a",
    "type": "attribute",
    "attribute": "href"
  }
}
```

**Default behavior:**

- When only `attribute` is provided, returns that attribute's value or `null`
- When `attributes` array provided, uses `attrMode` logic
- Compatible with current `attr:name` CLI syntax

---

### 3. **HTML**

Extract HTML markup from elements.

```rescript
{
  type: "html";
  htmlOptions?: {
    mode?: "inner" | "outer";       // Default: "inner"
    stripScripts?: boolean;         // Default: false - remove <script> tags
    stripStyles?: boolean;          // Default: false - remove <style> tags
  };
}
```

**Example:**

```json
{
  "description": {
    "selector": ".description",
    "type": "html",
    "htmlOptions": {
      "mode": "inner",
      "stripScripts": true
    }
  },
  "fullElement": {
    "selector": ".card",
    "type": "html",
    "htmlOptions": {
      "mode": "outer"
    }
  }
}
```

**Default behavior:**

- Returns `.innerHTML` of the matched element

---

### 4. **Number**

Extract and parse numeric values.

```rescript
{
  type: "number";
  numberOptions?: {
    stripNonNumeric?: boolean;      // Default: true - remove non-digit chars except .-
    pattern?: string;               // Regex to extract number (capture group 1)
    thousandsSeparator?: string;    // Default: "," - character to strip
    decimalSeparator?: string;      // Default: "." - decimal point character
    locale?: string;                // Locale-aware parsing (e.g., "de-DE", "en-US")
    allowNegative?: boolean;        // Default: true
    precision?: number;             // Round to N decimal places
    onError?: "null" | "text" | "default" | "error";  // Default: "null"
  };
}
```

**Parsing priority:**

1. If `pattern` is provided, extract capture group and parse
2. If `stripNonNumeric=true`, remove currency/formatting chars
3. Handle `thousandsSeparator` and `decimalSeparator`
4. Parse with `parseFloat`
5. Apply `precision` rounding if specified
6. If `NaN`, apply `onError` policy

**Example:**

```json
{
  "price": {
    "selector": ".price",
    "type": "number",
    "numberOptions": {
      "stripNonNumeric": true,
      "pattern": "\\$?([0-9,\\.]+)",
      "precision": 2,
      "onError": "null"
    }
  },
  "germanPrice": {
    "selector": ".preis",
    "type": "number",
    "numberOptions": {
      "thousandsSeparator": ".",
      "decimalSeparator": ",",
      "locale": "de-DE"
    }
  }
}
```

**Default behavior:**

- `stripNonNumeric: true`
- `thousandsSeparator: ","`
- `decimalSeparator: "."`
- Returns `null` on parse failure

**Common patterns:**

- Currency: `"\\$?([0-9,\\.]+)"` → `$1,234.56` → `1234.56`
- Percentage: `"([0-9\\.]+)%"` → `25.5%` → `25.5`
- Range: `"([0-9]+)-[0-9]+"` → `10-20` → `10` (first capture)

---

### 5. **Boolean**

Extract and parse boolean values.

```rescript
{
  type: "boolean";
  booleanOptions?: {
    mode?: "mapping" | "presence" | "attribute";  // Default: "mapping"
    trueValues?: string[];          // Case-insensitive strings that map to true
    falseValues?: string[];         // Case-insensitive strings that map to false
    attribute?: string;             // For mode="attribute", which attribute to check
    pattern?: string;               // Regex pattern (match = true, no match = false)
    onUnknown?: "false" | "null" | "error";  // Default: "false"
  };
}
```

**Modes:**

1. **`mapping`** (default): Compare text content against `trueValues` / `falseValues`
2. **`presence`**: Return `true` if selector matches any element, `false` otherwise
3. **`attribute`**: Return `true` if attribute exists and is truthy (non-empty, not "false")

**Example:**

```json
{
  "inStock": {
    "selector": ".stock-status",
    "type": "boolean",
    "booleanOptions": {
      "mode": "mapping",
      "trueValues": ["in stock", "available", "yes", "✓"],
      "falseValues": ["out of stock", "unavailable", "no"],
      "onUnknown": "null"
    }
  },
  "hasDiscount": {
    "selector": ".discount-badge",
    "type": "boolean",
    "booleanOptions": {
      "mode": "presence"
    }
  },
  "isChecked": {
    "selector": "input[type=checkbox]",
    "type": "boolean",
    "booleanOptions": {
      "mode": "attribute",
      "attribute": "checked"
    }
  },
  "patternMatch": {
    "selector": ".status",
    "type": "boolean",
    "booleanOptions": {
      "pattern": "active|enabled"
    }
  }
}
```

**Default behavior:**

- Mode: `mapping`
- `trueValues: ["true", "yes", "1"]`
- `falseValues: ["false", "no", "0"]`
- `onUnknown: "false"`

---

### 6. **DateTime**

Extract and parse date/time values.

```rescript
{
  type: "datetime";
  dateOptions?: {
    formats?: string[];             // Parsing format patterns (tries in order)
    timezone?: string;              // IANA timezone (e.g., "UTC", "America/New_York")
    output?: "iso8601" | "epoch" | "epochMillis" | "custom";  // Default: "iso8601"
    outputFormat?: string;          // Custom output format pattern
    strict?: boolean;               // Default: false - allow fuzzy parsing
    locale?: string;                // Locale for month/day names
    source?: "text" | "attribute";  // Default: "text"
    attribute?: string;             // When source="attribute"
  };
}
```

**Format tokens** (subset of common patterns):

- `yyyy` - 4-digit year
- `yy` - 2-digit year
- `MM` - 2-digit month
- `dd` - 2-digit day
- `HH` - 24-hour
- `hh` - 12-hour
- `mm` - minutes
- `ss` - seconds
- `a` - AM/PM

**Example:**

```json
{
  "publishedAt": {
    "selector": "time",
    "type": "datetime",
    "dateOptions": {
      "source": "attribute",
      "attribute": "datetime",
      "formats": ["ISO"],
      "output": "iso8601"
    }
  },
  "humanDate": {
    "selector": ".date",
    "type": "datetime",
    "dateOptions": {
      "formats": ["MMMM dd, yyyy", "MM/dd/yyyy", "yyyy-MM-dd"],
      "timezone": "UTC",
      "output": "iso8601"
    }
  },
  "timestamp": {
    "selector": ".timestamp",
    "type": "datetime",
    "dateOptions": {
      "formats": ["epoch"],
      "output": "epochMillis"
    }
  }
}
```

**Special format values:**

- `"ISO"` - ISO 8601 (e.g., `2024-03-15T10:30:00Z`)
- `"epoch"` - Unix timestamp (seconds)
- `"epochMillis"` - Unix timestamp (milliseconds)

**Default behavior:**

- Tries common formats: ISO 8601, RFC 2822, common date patterns
- Returns ISO 8601 string
- Returns `null` on parse failure

---

### 7. **Count**

Count the number of matched elements.

```rescript
{
  type: "count";
  countOptions?: {
    min?: number;                   // Minimum expected count
    max?: number;                   // Maximum expected count
  };
}
```

**Example:**

```json
{
  "reviewCount": {
    "selector": ".review",
    "type": "count"
  },
  "imageCount": {
    "selector": "img.gallery",
    "type": "count",
    "countOptions": {
      "min": 1,
      "max": 10
    }
  }
}
```

**Behavior:**

- Returns integer count of matched elements
- Validation warnings if count outside `min`/`max` range

---

### 8. **URL**

Extract and normalize URLs.

```rescript
{
  type: "url";
  urlOptions?: {
    base?: string;                  // Base URL for resolving relative URLs
    resolve?: boolean;              // Default: true - resolve relative to base
    validate?: boolean;             // Default: true - validate URL format
    protocol?: "http" | "https" | "any";  // Required protocol
    stripQuery?: boolean;           // Default: false - remove query string
    stripHash?: boolean;            // Default: false - remove fragment
    attribute?: string;             // Default: "href" for <a>, "src" for <img>
  };
}
```

**Example:**

```json
{
  "productUrl": {
    "selector": "a.product-link",
    "type": "url",
    "urlOptions": {
      "base": "https://example.com",
      "resolve": true,
      "protocol": "https"
    }
  },
  "canonicalUrl": {
    "selector": "link[rel=canonical]",
    "type": "url",
    "urlOptions": {
      "attribute": "href",
      "stripQuery": true
    }
  }
}
```

---

### 9. **JSON**

Extract and parse embedded JSON.

```rescript
{
  type: "json";
  jsonOptions?: {
    source?: "text" | "attribute";  // Default: "text"
    attribute?: string;             // When source="attribute"
    path?: string;                  // JSONPath to extract subset
    validate?: boolean;             // Default: true
    onError?: "null" | "text" | "error";  // Default: "null"
  };
}
```

**Example:**

```json
{
  "structuredData": {
    "selector": "script[type='application/ld+json']",
    "type": "json",
    "jsonOptions": {
      "path": "$.offers.price"
    }
  },
  "dataAttr": {
    "selector": ".widget",
    "type": "json",
    "jsonOptions": {
      "source": "attribute",
      "attribute": "data-config"
    }
  }
}
```

---

### 10. **List / Array**

Collect multiple matches into a typed array.

```rescript
{
  type: "list";
  listOptions?: {
    itemType?: "text" | "html" | "attribute" | "url";  // Default: "text"
    attribute?: string;             // When itemType="attribute"
    unique?: boolean;               // Default: false - deduplicate
    filter?: string;                // Regex pattern - only include matches
    limit?: number;                 // Max items to collect
    join?: string;                  // Join into string instead of array
  };
}
```

**Example:**

```json
{
  "categories": {
    "selector": ".category",
    "type": "list",
    "listOptions": {
      "itemType": "text",
      "unique": true
    }
  },
  "imageUrls": {
    "selector": "img",
    "type": "list",
    "listOptions": {
      "itemType": "attribute",
      "attribute": "src",
      "unique": true,
      "limit": 5
    }
  }
}
```

---

## Global Config

```rescript
{
  config?: {
    ignoreErrors?: boolean;         // Default: false - swallow field extraction errors
    limit?: number;                 // Default: 0 (unlimited) - max rows to extract
    rowSelector?: string;           // CSS selector for row root elements
    defaults?: {                    // Default options for each type
      text?: TextOptions;
      number?: NumberOptions;
      boolean?: BooleanOptions;
      datetime?: DateOptions;
      url?: URLOptions;
    };
    output?: {
      format?: "json" | "jsonl" | "csv";  // Default: "json"
      pretty?: boolean;             // Default: false - pretty-print JSON
      includeMetadata?: boolean;    // Default: false - add __meta fields
    };
  };
}
```

### Row Selector

When `rowSelector` is provided, extraction behavior changes:

1. Run `querySelectorAll(rowSelector)` to get row elements
2. For each row element, evaluate field selectors **relative to that row**
3. Each row becomes one output object
4. More intuitive than zip-by-first-field model

**Example:**

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

**Without rowSelector (legacy zip behavior):**

- Each field's selector runs against entire document
- Rows are created by zipping field results by index
- Row count = length of first field's results

**With rowSelector (recommended):**

- Each field's selector runs relative to row element
- Row count = number of elements matching `rowSelector`
- More reliable and intuitive

---

## Default Values

Global defaults applied when field options are not specified:

```json
{
  "config": {
    "defaults": {
      "text": {
        "trim": true,
        "normalizeWhitespace": false
      },
      "number": {
        "stripNonNumeric": true,
        "thousandsSeparator": ",",
        "decimalSeparator": ".",
        "onError": "null"
      },
      "boolean": {
        "mode": "mapping",
        "trueValues": ["true", "yes", "1"],
        "falseValues": ["false", "no", "0"],
        "onUnknown": "false"
      },
      "datetime": {
        "output": "iso8601",
        "timezone": "UTC"
      },
      "url": {
        "resolve": true,
        "validate": true
      }
    }
  }
}
```

---

## Complete Example

```json
{
  "name": "E-commerce Product Schema",
  "description": "Extract product information from e-commerce pages",
  "config": {
    "rowSelector": ".product-card",
    "limit": 0,
    "ignoreErrors": false,
    "defaults": {
      "number": {
        "stripNonNumeric": true,
        "thousandsSeparator": ",",
        "precision": 2
      },
      "boolean": {
        "trueValues": ["in stock", "available", "yes"],
        "falseValues": ["out of stock", "unavailable", "no"]
      }
    }
  },
  "fields": {
    "name": {
      "selector": "h2.product-name",
      "type": "text",
      "required": true,
      "textOptions": {
        "trim": true,
        "normalizeWhitespace": true
      }
    },
    "price": {
      "selector": ".current-price",
      "type": "number",
      "required": true,
      "numberOptions": {
        "pattern": "\\$?([0-9,\\.]+)"
      }
    },
    "originalPrice": {
      "selector": ".original-price",
      "type": "number",
      "default": null
    },
    "discount": {
      "selector": ".discount-percent",
      "type": "number",
      "numberOptions": {
        "pattern": "([0-9]+)%"
      }
    },
    "inStock": {
      "selector": ".stock-status",
      "type": "boolean",
      "required": true,
      "default": false
    },
    "hasShipping": {
      "selector": ".free-shipping-badge",
      "type": "boolean",
      "booleanOptions": {
        "mode": "presence"
      }
    },
    "rating": {
      "selector": ".rating",
      "type": "number",
      "numberOptions": {
        "pattern": "([0-9\\.]+)\\s*out of",
        "precision": 1
      }
    },
    "reviewCount": {
      "selector": ".review",
      "type": "count"
    },
    "imageUrl": {
      "selector": "img.product-image",
      "type": "attribute",
      "attributes": ["data-src", "src"],
      "attrMode": "firstNonEmpty"
    },
    "productUrl": {
      "selector": "a.product-link",
      "type": "url",
      "urlOptions": {
        "base": "https://example.com",
        "resolve": true
      }
    },
    "categories": {
      "selector": ".category-tag",
      "type": "list",
      "listOptions": {
        "itemType": "text",
        "unique": true
      }
    },
    "description": {
      "selector": ".description",
      "type": "html",
      "htmlOptions": {
        "mode": "inner",
        "stripScripts": true
      }
    },
    "publishedDate": {
      "selector": "time.published",
      "type": "datetime",
      "dateOptions": {
        "source": "attribute",
        "attribute": "datetime",
        "output": "iso8601"
      }
    },
    "structuredData": {
      "selector": "script[type='application/ld+json']",
      "type": "json",
      "jsonOptions": {
        "path": "$.offers"
      }
    }
  }
}
```

---

## Error Handling

### Field-level errors

When a field extraction fails:

1. **Required field missing**:
   - If `config.ignoreErrors = false`: abort and return error
   - If `config.ignoreErrors = true`: use `default` value or `null`

2. **Parse error** (e.g., invalid number):
   - Follow field's `onError` policy (`null`, `text`, `default`, or `error`)

3. **Validation error** (e.g., URL format invalid):
   - Follow field's validation policy

### Schema-level errors

- `InvalidJson`: Schema file is not valid JSON
- `MissingFields`: Required `fields` key is missing
- `InvalidFieldType`: Unknown field type specified
- `InvalidSelector`: CSS selector syntax error
- `InvalidOptions`: Invalid option value for field type

---

## Implementation Notes

**For implementors:**

1. **Parsing order**: Parse schema → validate structure → apply defaults → run extraction
2. **Selector evaluation**: Always use `querySelectorAll`, even for single-value types
3. **Type coercion**: Apply type-specific parsing after extraction, before output
4. **Error propagation**: Collect all errors in `ignoreErrors` mode, report at end
5. **Performance**: Cache compiled regexes, reuse DOM queries when possible
6. **Memory**: Stream output for large result sets

**Extension points:**

- Custom field types via plugins
- Custom validators
- Custom transform functions
- Output format plugins

---

## Versioning

Schemas should include a version field for forward compatibility:

```json
{
  "version": "2.0",
  "name": "My Schema"
}
```
