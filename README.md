# res-scrapy

A small command-line HTML scraper written in ReScript. It reads HTML from stdin
and writes JSON to stdout. Supports simple selector-based extraction and
schema-driven structured extraction.

**Key ideas**

- Read HTML from stdin, write results to stdout (JSON).
- Two extraction modes: selector-based (single|multiple) and schema-driven.
- Designed as a small, installable CLI: `res-scrapy` (see `package.json` `bin`).

**Requirements**

- Node.js >= 22.0.0

**Install & build**

Clone, install dependencies and build:

```bash
git clone https://github.com/MetalbolicX/res-scrapy.git
cd res-scrapy
npm install
npm run build
```

After building you can run the packaged script directly with `node` or link
it as a global CLI:

```bash
# run directly (recommended during development)
node dist/main.js -h

# or install locally for global use
npm link
res-scrapy -h
```

Scripts available in `package.json`:

- `npm run build` — compile ReScript and bundle (`rescript && rolldown -c`)
- `npm start` — run `node dist/main.js`
- `npm run res:dev` — ReScript watch mode

**Usage**

res-scrapy reads HTML from stdin and accepts options via flags. Output is JSON
printed to stdout; errors are logged to stderr and the process exits with code
1 on failure.

```
res-scrapy [options]

Options:
  -h, --help        Display this help message
  -s, --selector    CSS selector to extract data
  -m, --mode        Extraction mode: single | multiple (default: single)
  -t, --text        Extract textContent instead of outer HTML (boolean)
  -c, --schema      Inline JSON schema (string)
  -p, --schemaPath  Path to a schema JSON file
```

Notes:

- When `--schema` or `--schemaPath` is provided the CLI performs structured
  extraction using the schema and ignores `--selector`/`--mode`/`--text`.
- `--mode single` returns the first match (as a JSON array with 0 or 1 item).
- `--mode multiple` returns all matches as a JSON array.

**Examples**

# Selector: multiple matches, extract text

```bash
cat page.html | res-scrapy -s '.product' -m multiple -t
```

# Selector: single match

```bash
cat page.html | res-scrapy -s '.title' -m single -t
```

# Inline schema (small schemas can be passed as a single JSON string)

```bash
cat page.html | res-scrapy -c '{"fields":{"title":{"selector":".title","type":"text"}}}'
```

# Schema from file

```bash
cat page.html | res-scrapy -p ./schema-product.json
```

**Schema format (short)**

The schema is a JSON object with a top-level `fields` entry. Each field has a
CSS `selector`, a `type`, and optional flags like `required` and `default`.

Supported field types: `text`, `html`, `number`, `boolean`, `attribute`.
When using `attribute` the field must also include an `attribute` key with the
attribute name.

Example schema:

```json
{
  "name": "Products",
  "fields": {
    "title": { "selector": ".product-title", "type": "text", "required": true },
    "price": { "selector": ".price", "type": "number" },
    "url": {
      "selector": ".product-link",
      "type": "attribute",
      "attribute": "href"
    }
  },
  "config": { "ignoreErrors": false, "limit": 0 }
}
```

Behavior notes (schema extraction):

- Each field is queried independently from the document root.
- Rows are produced by zipping field match lists; the row count is taken from
  the first field's match list.
- Missing values use the field's `default` or `null`.
- `required: true` makes missing values a fatal error unless
  `config.ignoreErrors` is set to `true`.

**Exit codes**

- `0` — success
- `1` — error (parse error, missing selector, schema errors, read errors, etc.)

**Contributing**

Contributions welcome. Please open issues or pull requests on
https://github.com/MetalbolicX/res-scrapy.

**License**

MIT (see LICENSE)
