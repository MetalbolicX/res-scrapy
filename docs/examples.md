# Examples & Use Cases

This page collects practical, runnable examples showing how to use the res-scrapy CLI. Each case includes a short description, a sample HTML snippet (when useful), the CLI command, and the expected JSON output.

## Quick CLI Reference

- `-s` (`--selector`) — CSS selector to target element(s)
- `-m` (`--mode`) — multiple mode: when present the extractor returns all matches (otherwise single)
- `-e` (`--extract`) — what to extract: `outerHtml`, `innerHtml`, `text`, or `attr:<name>` (e.g. `attr:href`)
- `-c` (`--schema`) — inline JSON schema for structured extraction
- `-p` (`--schemaPath`) — path to a JSON schema file for structured extraction
- `-t` (`--table`) — extract an HTML `<table>` as a JSON array of row objects

> [!Note] The CLI reads HTML from stdin and writes JSON to stdout. Many examples below use `echo`/`printf` or file redirection to demonstrate usage.

## 1. Simple Selector Extraction (no schema)

1. Extract text from the first match

Sample HTML:

```html
<h1>Hello World</h1>
```

Command:

```bash
echo '<h1>Hello World</h1>' | res-scrapy -s 'h1' -e text
```

Expected output:

```json
["Hello World"]
```

2. Extract all matching attributes (links)

Sample HTML:

```html
<a href="/page1">Link 1</a><a href="/page2">Link 2</a>
```

Command:

```bash
echo '<a href="/page1">Link 1</a><a href="/page2">Link 2</a>' | res-scrapy -s 'a' -m -e 'attr:href'
```

Expected output:

```json
["/page1", "/page2"]
```

3. Extract inner or outer HTML

Sample HTML:

```html
<div class="content"><p>Paragraph</p></div>
```

Commands:

```bash
# inner HTML
echo '<div class="content"><p>Paragraph</p></div>' | res-scrapy -s '.content' -e innerHtml

# outer HTML
echo '<div class="content"><p>Paragraph</p></div>' | res-scrapy -s '.content' -e outerHtml
```

Expected outputs:

```json
// innerHtml
["<p>Paragraph</p>"]

// outerHtml
["<div class=\"content\"><p>Paragraph</p></div>"]
```

---

## 2. Table Extraction

1. Extract the first `<table>` found (default)

Sample HTML:

```html
<table>
  <thead>
    <tr>
      <th>product</th>
      <th>price</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Widget A</td>
      <td>$9.99</td>
    </tr>
  </tbody>
</table>
```

Command:

```bash
echo '<table>...</table>' | res-scrapy -t
```

Expected output:

```json
[{ "product": "Widget A", "price": "$9.99" }]
```

2. Extract a specific table by selector

Command:

```bash
cat examples/sample.html | res-scrapy -t -s '#prices'
```

**Expected behavior:** the CLI will run the table extractor against the selected table; headers become object keys and each row becomes an object in the output array.

---

## 3. Schema-Driven Structured Extraction

Schemas let you declare typed fields (text, number, boolean, datetime, url, list, json, count, etc.). Use `--schema` (inline JSON) or `--schemaPath` (file).

1. Product data — run a reusable schema file

The repository includes `examples/schema-product.json` and `examples/sample.html` which can be used together.

Command:

```bash
res-scrapy --schemaPath examples/schema-product.json < examples/sample.html
```

Expected output (array of product objects):

```json
[
  {
    "title": "Widget A",
    "price": 9.99,
    "description": "A bright widget.",
    "link": "/buy/widget-a",
    "inStock": true
  },
  {
    "title": "Widget B",
    "price": null,
    "description": "A mysterious widget.",
    "link": "/buy/widget-b",
    "inStock": false
  }
]
```

2. Small inline schema (quick test)

Sample HTML:

```html
<div class="product">
  <h1>Awesome Product</h1>
  <span class="price">$29.99</span>
  <div class="in-stock">In Stock</div>
</div>
```

Command (inline schema):

```bash
echo '<div class="product"><h1>Awesome Product</h1><span class="price">$29.99</span><div class="in-stock">In Stock</div></div>' \
  | res-scrapy --schema '{"fields": {"name": {"selector": "h1","type": "text"}, "price": {"selector": ".price","type": "number","numberOptions": {"stripNonNumeric": true}}, "inStock": {"selector": ".in-stock","type": "boolean","booleanOptions": {"trueValues": ["in stock"]}}}}'
```

Expected output:

```json
[{ "name": "Awesome Product", "price": 29.99, "inStock": true }]
```

3. Row-based extraction (multiple repeating blocks)

When extracting repeated items on a page, prefer `config.rowSelector` so every row is evaluated relative to its container.

Inline schema example:

```json
{
  "config": { "rowSelector": ".job-card" },
  "fields": {
    "title": { "selector": "h2", "type": "text" },
    "company": { "selector": ".company", "type": "text" },
    "location": { "selector": ".location", "type": "text" }
  }
}
```

Command (inline):

```bash
cat jobs-page.html | res-scrapy --schema '{...}'
```

Expected output: one object per `.job-card` element with the declared fields.

---

## 4. Field-Type Patterns & Common Tasks

1. Currency / Percentage parsing (`number` with pattern / stripNonNumeric)

Schema snippet:

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

2. Human-readable booleans

Schema snippet:

```json
{
  "inStock": {
    "selector": ".stock",
    "type": "boolean",
    "booleanOptions": {
      "mode": "mapping",
      "trueValues": ["in stock", "available", "yes"],
      "falseValues": ["out of stock", "no"]
    }
  }
}
```

3. Badge presence (presence-mode boolean)

```json
{
  "hasBadge": {
    "selector": ".discount-badge",
    "type": "boolean",
    "booleanOptions": { "mode": "presence" }
  }
}
```

4. Lazy-loaded images (attribute fallback)

```json
{
  "image": {
    "selector": "img",
    "type": "attribute",
    "attributes": ["data-lazy-src", "data-src", "src"],
    "attrMode": "firstNonEmpty"
  }
}
```

5. Extract JSON-LD or embedded JSON

```json
{
  "offersPrice": {
    "selector": "script[type='application/ld+json']",
    "type": "json",
    "jsonOptions": { "path": "$.offers.price" }
  }
}
```

6. Collect tags or categories (`list`)

```json
{
  "tags": {
    "selector": ".tag",
    "type": "list",
    "listOptions": { "itemType": "text", "unique": true }
  }
}
```

---

## 5. Advanced Patterns & Error Handling

1. Use `ignoreErrors` and field `default` when the site is flaky

Schema snippet:

```json
{
  "config": { "ignoreErrors": true },
  "fields": {
    "price": { "selector": ".price", "type": "number", "default": null }
  }
}
```

With `ignoreErrors: true` the extractor will attempt to continue and fill missing/failed fields with `default` or `null` instead of aborting.

2. Load schema from a file (reusable)

```bash
res-scrapy --schemaPath examples/schema-product.json < examples/sample.html
```

3. Debugging tips

- When a schema produces no rows, check if `config.rowSelector` is set correctly. Without `rowSelector` the extractor zips fields by index (legacy behavior).
- Use `--mode -s '<selector>' -e attr:name` to quickly probe which elements match and what attributes they expose.

---

## Where to go next

- See `/SCHEMA-SPEC.md` for the full schema reference and all type options.
- See `/SCHEMA-EXAMPLES.md` for more complete schema examples (e-commerce, blogs, dates, tables, nested data).
- Use the `examples/cases/` fixtures in the repository to test specific behaviors (dates, attributes, inner/outer HTML, lists, JSON-LD).

If you want, I can also add runnable example files under `docs/examples/` or wire copy buttons for each command — tell me which examples you'd like to make executable in the repo.
