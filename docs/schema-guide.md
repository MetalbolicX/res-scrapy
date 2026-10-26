# Schema Guide

This is the canonical, consolidated schema guide for res-scrapy. It is intended to be the single authoritative page for schema-driven extraction: CLI cheat-sheet, top-level concepts, practical examples (HTML + schema + CLI + expected JSON), and a compact but complete per-type reference.

---

## CLI Cheat-sheet

Quick reference for the flags at your disposal:

- `-s` (`--selector`) — CSS selector to target element(s).
- `-v` (`--version`) — display CLI version.
- `-m` (`--mode`) — multiple mode: when present the extractor returns all matches (otherwise single).
- `-e` (`--extract`) — what to extract: `outerHtml`, `innerHtml`, `text`, or `attr:<name>` (e.g. `attr:href`).
- `-c` (`--schema`) — inline JSON schema for structured extraction.
- `-p` (`--schemaPath`) — path to a JSON schema file for structured extraction.
- `-t` (`--table`) — extract an HTML `<table>` as a JSON array of row objects.
 - `-u` (`--url`) — URL template for fetching pages directly (e.g. `https://site.com/page-{1..10}.html`).
- `-j` (`--concurrency`) — max concurrent fetches in URL mode (default: 5).
- `--user-agent` — custom User-Agent header for URL mode.
- `--timeout` — request timeout in seconds (default: 30).
- `--retry` — total fetch attempts per URL on retryable failures (default: 3); waits ~2s before the 2nd attempt, then ~4s, 8s, ... (doubling, ±0.5s jitter).
- `--delay` — minimum delay between request starts in ms.
- `--header` — custom HTTP header in "Key: Value" format (repeatable).
- `--cookie` — cookie value (repeatable, sugar for `--header`).

> [!Note] The CLI reads HTML from stdin and writes JSON to stdout. Many examples below use `echo`/`printf` or file redirection to demonstrate usage. Use `--output/-o` to write results to a file; when writing to a file you can control the file format with `--format/-f` (`json` or `ndjson`). The `--format` flag is ignored when `--output` is not provided — stdout always uses the JSON array format.

Examples:

1. Inline schema (quick test):

```sh
echo '<html>...</html>' | res-scrapy --schema '{"fields": {"title": {"selector": "h1", "type": "text"}}}'
```

2. Schema from file (recommended)

```sh
res-scrapy --schemaPath product-schema.json < page.html
```

3. Table extraction (targeted)

```sh
cat page.html | res-scrapy --table --selector '#products'
```

4. Save output to a file (JSON)

```sh
echo '<html>...</html>' | res-scrapy -s '.product-title' -m -e text -o results.json
# Writes a JSON array to results.json
```

5. Save NDJSON (newline-delimited JSON)

```sh
echo '<html>...</html>' | res-scrapy -s '.product-card' -m -e text -o results.ndjson -f ndjson
# results.ndjson will contain one JSON object per line
```

---

## Minimal Valid Schema

```json
{
  "fields": {
    "title": {
      "selector": "h1",
      "type": "text"
    }
  }
}
```

> [!Tip] Use `--schema` for quick experiments and `--schemaPath` for production schemas.

---

## Top-level concepts

- `fields` (required): map of output property name → field definition
- `config` (optional): global settings (e.g., `rowSelector`, `ignoreErrors`, `limit`, `defaults`)
- `rowSelector` (strongly recommended for repeated items): makes extraction run relative to each matching row element

---

## rowSelector — the most important option

When present, the extractor treats each element matching `rowSelector` as an output row and evaluates each field selector relative to that row. This is the recommended and most robust model for repeated items (product cards, list items, search results).

Without `rowSelector` the extractor uses the legacy zip-by-index behavior: each field selector runs against the whole document and rows are created by zipping field results by index (fragile and often surprising).

Example (row-based):

```json
{
  "config": { "rowSelector": ".product-card" },
  "fields": {
    "name": { "selector": "h2", "type": "text" },
    "price": { "selector": ".price", "type": "number" }
  }
}
```

Example (legacy, do not use for repeated items):

```json
{
  "fields": {
    "name": { "selector": ".product-name", "type": "text" },
    "price": { "selector": ".product-price", "type": "number" }
  }
}
```

---

## Quick patterns (copy-paste)

- Price parsing (strip currency and parse number):

```json
{
  "price": {
    "selector": ".price",
    "type": "number",
    "numberOptions": {
      "stripNonNumeric": true,
      "precision": 2
    }
  }
}
```

- Lazy image fallback (try data-src then src):

```json
{
  "image": {
    "selector": "img",
    "type": "attribute",
    "attributes": ["data-src", "src"],
    "attrMode": "firstNonEmpty"
  }
}
```

- Badge presence (boolean by presence):

```json
{
  "hasBadge": {
    "selector": ".badge",
    "type": "boolean",
    "booleanOptions": { "mode": "presence" }
  }
}
```

---

## Schema Mode: end-to-end example

Full example showing sample HTML, a schema file, the CLI command, and expected JSON output.

Sample HTML:

```html
<article class="product-card">
  <h2>Premium Widget</h2>
  <span class="price">$49.99</span>
  <img data-src="https://cdn.example.com/widget.jpg" src="/fallback.jpg" />
  <span class="stock-status">In Stock</span>
</article>
```

Schema (product-schema.json):

```json
{
  "config": { "rowSelector": ".product-card" },
  "fields": {
    "name": { "selector": "h2", "type": "text" },
    "price": {
      "selector": ".price",
      "type": "number",
      "numberOptions": { "stripNonNumeric": true, "precision": 2 }
    },
    "imageUrl": {
      "selector": "img",
      "type": "attribute",
      "attributes": ["data-src", "src"],
      "attrMode": "firstNonEmpty"
    },
    "inStock": {
      "selector": ".stock-status",
      "type": "boolean",
      "booleanOptions": {
        "mode": "mapping",
        "trueValues": ["in stock", "available", "yes"]
      }
    }
  }
}
```

Command:

```sh
echo '<article class="product-card">...</article>' | res-scrapy --schemaPath product-schema.json
```

Expected output:

```json
[
  {
    "name": "Premium Widget",
    "price": 49.99,
    "imageUrl": "https://cdn.example.com/widget.jpg",
    "inStock": true
  }
]
```

---

## Table Mode (--table)

Use table mode when data is already in an HTML `<table>` and you only need raw string values. Table mode converts the first header row into object keys and emits an array of objects.

Sample HTML:

```html
<table id="products">
  <thead>
    <tr>
      <th>Product</th>
      <th>Price</th>
      <th>In Stock</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Widget A</td>
      <td>$9.99</td>
      <td>Yes</td>
    </tr>
    <tr>
      <td>Widget B</td>
      <td>$14.99</td>
      <td>No</td>
    </tr>
  </tbody>
</table>
```

Command:

```sh
cat page.html | res-scrapy --table --selector '#products'
```

Output:

```json
[
  { "Product": "Widget A", "Price": "$9.99", "In Stock": "Yes" },
  { "Product": "Widget B", "Price": "$14.99", "In Stock": "No" }
]
```

When to use table vs schema mode:

<!-- tabs:start -->

#### Use Table Mode when...

- Data is already in a `<table>` element
- You want raw string values (no type conversion)
- Quick one-off extraction is sufficient

#### Use Schema Mode when...

- You need typed fields (numbers, booleans, dates)
- Data lives in cards/divs or complex layouts
- You need to clean or transform values during extraction

<!-- tabs:end -->

---

## Field Types (summary with key options and examples)

res-scrapy supports these field types: text, attribute, html, number, boolean, datetime, count, url, json, list.

Below are concise summaries with the most-used options and a short example for each type.

### 1. Text

Purpose: extract textContent.

Key options:

- `trim` (default true).
- `normalizeWhitespace`.
- `pattern` (regex capture).

Example:

```json
{
  "title": {
    "selector": "h1",
    "type": "text",
    "textOptions": {
      "trim": true
    }
  }
}
```

### 2. Attribute

Purpose: extract attributes (href/src/data-\*).

Key options:

- `attribute` (legacy single).
- `attributes` (array).
- `attrMode` (`first`, `firstNonEmpty` (default), `all`, `join`).
- `attrJoin`.

Example (lazy image):

```json
{
  "image": {
    "selector": "img",
    "type": "attribute",
    "attributes": ["data-src", "src"],
    "attrMode": "firstNonEmpty"
  }
}
```

### 3. HTML

Purpose: extract markup.

Key options:

- `htmlOptions.mode` (`inner` `default`, `outer`).
- `stripScripts`.
- `stripStyles`.

Example:

```json
{
  "description": {
    "selector": ".description",
    "type": "html",
    "htmlOptions": {
      "mode": "inner",
      "stripScripts": true
    }
  }
}
```

### 4. Number

Purpose: parse numeric values (currency, percent, scientific notation).

Default cleanup preserves scientific notation: `1e5 → 100000`, `1.5E-3 → 0.0015`,
`-2e3 → -2000`, and `2e+3 → 2000`. Letters in prose are still stripped
(`5 items each → 5`); cleanup does not join spaced fragments into exponents.

Percent signs are stripped without division by 100: `45% → 45`, not `0.45`.
Decimal comma requires configuration: `3,14 → 314` by default, versus `3.14`
with `numberOptions.decimalSeparator: ","`. Separator normalization runs before
cleanup. Parsing remains permissive: `1e → 1` and `1.2.3 → 1.2`.

Key options:

- `stripNonNumeric` (default true).
- `pattern` (regex capture).
- `thousandsSeparator`.
- `decimalSeparator`.
- `precision`.

Example:

```json
{
  "price": {
    "selector": ".price",
    "type": "number",
    "numberOptions": {
      "stripNonNumeric": true,
      "pattern": "\\$?([0-9,\\.]+)",
      "precision": 2
    }
  }
}
```

### 5. Boolean

Purpose: interpret truthy/falsey values.

Key options:

- `mode` (`mapping` default, `presence`, `attributeCheck`).
- `trueValues`.
- `falseValues`.
- `attribute`.
- `onUnknown` (`false` default).

Example (presence):

```json
{
  "hasDiscount": {
    "selector": ".discount-badge",
    "type": "boolean",
    "booleanOptions": {
      "mode": "presence"
    }
  }
}
```

### 6. DateTime

Purpose: parse dates and normalize output.

Key options:

- `formats` (array).
- `timezone`.
- `output` (`iso8601` default).
- `outputFormat`.
- `source` (`text`/`attribute`).

Example:

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
  }
}
```

### 7. Count

Purpose: return integer count of matched elements.

Key options:

- `min`.
- `max` (validation).

Example:

```json
{
  "reviewCount": {
    "selector": ".review",
    "type": "count"
  }
}
```

### 8. URL

Purpose: extract and normalize URLs.

Key options:

- `base`.
- `resolve` (default true).
- `validate` (default true).
- `protocol` (`http`/`https`).
- `stripQuery`.
- `stripHash`.
- `attribute`.

> [!Note]
> For safety, URLs with unsafe schemes (for example `javascript:` and `data:`) are rejected.

Example:

```json
{
  "productUrl": {
    "selector": "a.product-link",
    "type": "url",
    "urlOptions": {
      "base": "https://example.com",
      "resolve": true
    }
  }
}
```

### 9. JSON

Purpose: extract and parse embedded JSON (script[type=application/ld+json] or data- attributes).

Key options:

- `source` (`text`/`attribute`).
- `attribute`.
- `path` (dot notation, e.g. `offers.price`).

Example:

```json
{
  "ld": {
    "selector": "script[type=\"application/ld+json\"]",
    "type": "json",
    "jsonOptions": {
      "path": "$.offers.price"
    }
  }
}
```

### 10. List

Purpose: collect multiple matches into an array of typed items.

Key options:

- `itemType` (`text` default).
- `attribute` (for attribute items).
- `unique`.
- `filter` (regex).
- `limit`.
- `join` (return string).

Example:

```json
{
  "categories": {
    "selector": ".category",
    "type": "list",
    "listOptions": {
      "itemType": "text",
      "unique": true
    }
  }
}
```

---

## Global config and defaults

Removed keys: `numberOptions.onError`, `dateOptions.strict`, `jsonOptions.onError`, `config.defaults.number.onError`, and `config.defaults.datetime.strict` are not implemented and now fail schema validation instead of being silently ignored.

Top-level `config` keys you will use:

- `rowSelector` (string): root selector for row-based extraction
- `ignoreErrors` (boolean): controls required-field-missing and table-column extraction errors (default: false; see [Error handling](#error-handling))
- `limit` (number): max rows to return (0 = unlimited). Explicit `null` is accepted and means unlimited (same as `0`).
- `defaults`: object to set per-type default options (text, number, boolean, datetime, url)

Default values (summary):

- Text: `trim: true`
- Number: `stripNonNumeric: true`
- Boolean: `mode: mapping`, `trueValues: ["true","yes","1"]`, `onUnknown: false`
- DateTime: `output: iso8601`, `timezone: UTC`
- URL: `resolve: true`, `validate: true`

---

## Error handling

`ignoreErrors` (default `false`) governs two situations. (1) Required fields: when a required field matches nothing, extraction fails unless `ignoreErrors` is true; when true, the field is assigned its configured `default` value or `null` and the row continues. (2) Table field columns: with `ignoreErrors` true, a cell whose extraction fails is replaced with that column's configured default or `null` instead of failing the row. This does not suppress other extraction errors elsewhere. If no rows match at all, extraction returns an empty result regardless of the flag; required-missing errors require an existing row.

Other field-level failures follow these rules:

1. Unsupported inert options are rejected during schema validation: `numberOptions.onError`, `dateOptions.strict`, and `jsonOptions.onError` (including corresponding number and datetime defaults).
2. Validation errors (e.g., URL invalid): treated per field policy

Schema-level validation errors include: invalid JSON, missing `fields`, invalid field type, invalid selector, invalid options.

---

## Complete product schema example (copyable)

```json
{
  "name": "E-commerce Product Schema",
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
        "falseValues": ["out of stock", "no"]
      }
    }
  },
  "fields": {
    "name": { "selector": "h2.product-name", "type": "text", "required": true },
    "price": {
      "selector": ".current-price",
      "type": "number",
      "numberOptions": { "pattern": "\\$?([0-9,\\.]+)" }
    },
    "imageUrl": {
      "selector": "img.product-image",
      "type": "attribute",
      "attributes": ["data-src", "src"],
      "attrMode": "firstNonEmpty"
    },
    "inStock": { "selector": ".stock-status", "type": "boolean" }
  }
}
```
