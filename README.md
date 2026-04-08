# res-scrapy

> HTML CLI Scraper that extracts the content you need.

Command-line HTML scraper written in ReScript offers a flexible configuration for extracting content from HTML documents using CSS selectors. It supports both single and multiple results, as well as schema-driven structured extraction for more specific data needs.

**Supported Versions:**

![Node.js](https://img.shields.io/badge/node->=22.0.0-blue)
![ReScript](https://img.shields.io/badge/rescript->=12.0.0-red)
![node-html-parser](https://img.shields.io/badge/node--html--parser->=7.1.0-blue)

## Features

- Read HTML from `stdin` and extract content using CSS selectors.
- Extract `outerHtml`, `innerHtml`, `text`, or an element attribute (`attr:name`).
- Exttract tables as JSON arrays of objects.
- Support for single or multiple results (`--mode` / `-m`).
- Schema-driven structured extraction via `--schema` (inline JSON) or
  `--schemaPath` (path to a `.json` schema file).
- Outputs JSON to `stdout`, prints errors to `stderr` and exits non-zero on failure.

## Install & Build

Clone the repo and install dependencies:

```sh
git clone https://github.com/MetalbolicX/res-scrapy.git
cd res-scrapy
pnpm install
```

Compile the ReScript sources:

```sh
pnpm run res:build
```

During development you can watch ReScript sources:

```sh
pnpm run res:dev
```

The package exposes a `bin` entry (`res-scrapy`) and the built CLI is
`dist/main.mjs`.

## Usage

The CLI reads HTML from `stdin` and writes a JSON array (or object) to
`stdout`.

Basic help (built-in):

```sh
Usage: res-scrapy command [options]
  -h, --help        Display this help message
  -s, --selector    Specify a CSS selector to extract data
  -m, --mode        Extract multiple results (single by default)
  -e, --extract     What to extract: outerHtml (default), innerHtml, text, or attr:<name>
  -c, --schema      Specify the schema to use
  -p, --schemaPath  Specify the path to the schema
  -t, --table       Extract a table as JSON: pair with --selector to target a specific table (default to "table")
```

### Examples:

1. Extract the text of the first matching element.

```sh
cat examples/sample.html | res-scrapy -s '.product-title' -e text
```

2. Extract all links (attribute) from a document.

```sh
curl -s 'https://example.com' | res-scrapy -s 'a.article-link' -m -e 'attr:href'
```

## Schema-driven extraction

When `--schema` (inline JSON) or `--schemaPath` (file) is provided, the
tool attempts structured extraction according to the schema.

**Schema format:**

```json
{
  "name": "Schema name (optional)",
  "description": "Schema description (optional)",
  "fields": {
    "fieldName": {
      "selector": "CSS selector",
      "type": "text|attribute|html|number|boolean",
      "required": true|false,
      "default": "default value"
    }
  },
  "config": {
    "ignoreErrors": true|false,
    "limit": number
  }
}
```

**Field Types:**

- `text`: Extract the text content of the element.
- `attribute`: Extract a specific attribute (e.g. `attr:href`).
- `html`: Extract the inner HTML of the element.
- `number`: Extract and parse as a number.
- `boolean`: Extract and parse as a boolean (e.g. "true"/"false").

### Example schema:

1. Inline JSON schema:

```sh
echo '<div class="product">
  <h1>Awesome Product</h1>
  <span class="price">$29.99</span>
  <span class="original-price">$39.99</span>
  <div class="in-stock">In Stock</div>
</div>' | res-scrapy --schema '{
  "fields": {
    "name": {"selector": "h1", "type": "text"},
    "price": {"selector": ".price", "type": "number"},
    "originalPrice": {"selector": ".original-price", "type": "number"},
    "inStock": {"selector": ".in-stock", "type": "boolean", "trueValue": "In Stock"}
  }
}'
```

**Output:**

```json
[
  {
    "name": "Awesome Product",
    "price": 29.99,
    "originalPrice": 39.99,
    "inStock": true
  }
]
```

## License

Released under [MIT](/LICENSE) by [@MetalbolicX](https://github.com/MetalbolicX).
