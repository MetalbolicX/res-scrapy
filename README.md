# res-scrapy

[![npm version](https://img.shields.io/npm/v/res-scrapy.svg)](https://www.npmjs.com/package/res-scrapy)
![Node.js](https://img.shields.io/badge/node->=22.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green.svg)

> **The CLI tool that turns HTML into structured JSON with zero code.**

Extract data from any HTML source—websites, files, or API responses—using simple CSS selectors or powerful JSON schemas. Built with ReScript for reliability and speed.

## Why res-scrapy?

- **Zero-code data extraction** – No programming required, just CSS selectors
- **10 built-in field types** – Text, numbers, booleans, dates, URLs, JSON, lists, and more
- **Smart row-based extraction** – Perfect for product listings, search results, tables
- **Table mode** – Convert HTML tables to JSON instantly
- **Schema-driven** – Reusable, version-controlled extraction configs
- **Pipe-friendly** – Works seamlessly with `curl`, `cat`, and other CLI tools

## Installation

Install globally (recommended):

```bash
npm install -g res-scrapy
```

Or use without installing:

```bash
npx res-scrapy -h
```

**Requirements:** Node.js >= 22.0.0

## Quick Start Examples

### 1. Extract text with a CSS selector

```bash
curl -s https://example.com | res-scrapy -s 'h1' -e text
# ["Welcome to Example"]
```

### 2. Extract all links from a page

```bash
curl -s https://example.com | res-scrapy -s 'a' -m -e 'attr:href'
# ["/about", "/contact", "/products"]
```

### 3. Convert an HTML table to JSON

```bash
curl -s https://example.com/products | res-scrapy -t -s '#price-table'
# [{"Product": "Widget A", "Price": "$9.99"}, {"Product": "Widget B", "Price": "$14.99"}]
```

### 4. Schema-driven extraction (row-based)

Create `product-schema.json`:

```json
{
  "config": { "rowSelector": ".product-card" },
  "fields": {
    "name": { "selector": "h2", "type": "text" },
    "price": {
      "selector": ".price",
      "type": "number",
      "numberOptions": { "stripNonNumeric": true }
    },
    "inStock": {
      "selector": ".stock-status",
      "type": "boolean",
      "booleanOptions": {
        "trueValues": ["in stock", "available"]
      }
    }
  }
}
```

Run it:

```bash
curl -s https://shop.example.com | res-scrapy --schemaPath product-schema.json
# Result: [{"name": "Premium Widget", "price": 49.99, "inStock": true}, ...]
```

## CLI Reference

```
Usage: res-scrapy [options]

Options:
  -h, --help         Display help message
  -s, --selector     CSS selector to target element(s)
  -m, --mode         Extract multiple results (single by default)
  -e, --extract      What to extract: outerHtml, innerHtml, text, or attr:<name>
  -c, --schema       Inline JSON schema for structured extraction
  -p, --schemaPath   Path to JSON schema file
  -t, --table        Extract HTML table as JSON array
```

> [!NOTE] The CLI reads HTML from **stdin** and outputs JSON to **stdout**.

## Key Features

### 10 Field Types for Structured Data

| Type        | Purpose                   | Example Use Case               |
| ----------- | ------------------------- | ------------------------------ |
| `text`      | Extract text content      | Product names, descriptions    |
| `attribute` | Extract HTML attributes   | `href`, `src`, `data-*`        |
| `html`      | Extract raw HTML markup   | Preserving formatting          |
| `number`    | Parse numeric values      | Prices with currency stripping |
| `boolean`   | Convert to true/false     | Stock status, availability     |
| `datetime`  | Parse and normalize dates | Published dates, timestamps    |
| `url`       | Extract and resolve URLs  | Absolute links from relative   |
| `json`      | Parse embedded JSON-LD    | Schema.org data                |
| `list`      | Collect multiple values   | Tags, categories               |
| `count`     | Count matching elements   | Review counts, item totals     |

### Row-Based Extraction (Recommended)

Use `config.rowSelector` to extract repeating items like product cards or search results. Each row becomes a JSON object with fields evaluated relative to that row.

```json
{
  "config": { "rowSelector": ".job-card" },
  "fields": {
    "title": { "selector": "h2", "type": "text" },
    "company": { "selector": ".company", "type": "text" }
  }
}
```

### Table Mode

Quickly convert HTML tables to JSON without writing schemas:

```bash
cat page.html | res-scrapy --table --selector '#data-table'
```

### Error Handling

- `config.ignoreErrors: true` – Continue extraction when fields fail
- Field-level `default` values for missing data
- `onError` policies per field: `null`, `text`, `default`, or `error`

## Documentation

📖 **Full documentation is available on [GitHub Pages](https://metalbolicx.github.io/res-scrapy/)**

- [Getting Started Guide](https://metalbolicx.github.io/res-scrapy/#/getting-started) – Installation and first steps
- [Schema Guide](https://metalbolicx.github.io/res-scrapy/#/schema-guide) – Complete schema reference with examples
- [Examples](https://metalbolicx.github.io/res-scrapy/#/examples) – Real-world use cases and patterns

## Development

Clone and build from source:

```bash
git clone https://github.com/MetalbolicX/res-scrapy.git
cd res-scrapy
pnpm install
pnpm run res:build
```

Link locally for testing:

```bash
npm link
res-scrapy -h
```

## License

Released under [MIT](/LICENSE) by [@MetalbolicX](https://github.com/MetalbolicX).

---

**Built with** [ReScript](https://rescript-lang.org/) · **Powered by** [node-html-parser](https://github.com/taoqf/node-html-parser)
