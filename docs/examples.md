# Examples & Use Cases

This page collects practical, runnable examples showing how to use the res-scrapy CLI. Each case includes a short description, a sample HTML snippet (when useful), the CLI command, and the expected JSON output.

## 1. Simple Selector Extraction (no schema)

1. Extract text from the first match

Sample HTML:

```html
<h1>Hello World</h1>
```

Command:

```sh
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

```sh
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

```sh
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

```sh
echo '<table>...</table>' | res-scrapy -t
```

Expected output:

```json
[{ "product": "Widget A", "price": "$9.99" }]
```

2. Extract a specific table by selector

Command:

```sh
cat examples/sample.html | res-scrapy -t -s '#prices'
```

**Expected behavior:** the CLI will run the table extractor against the selected table; headers become object keys and each row becomes an object in the output array.

---

## 3. Schema-Driven Structured Extraction

Schemas let you declare typed fields (text, number, boolean, datetime, url, list, json, count, etc.). Use `--schema` (inline JSON) or `--schemaPath` (file).

1. Product data — run a reusable schema file

The repository includes `examples/schema-product.json` and `examples/sample.html` which can be used together.

Command:

```sh
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

```sh
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

```sh
cat jobs-page.html | res-scrapy --schema '{...}'
```

Expected output: one object per `.job-card` element with the declared fields.

## 3.1 Save output to file

1. Save output to a file (JSON)

Sample input & command:

```sh
echo '<div class="product"><div class="product-item">Product A</div><div class="product-item">Product B</div></div>' \
  | res-scrapy -s '.product-item' -m -e text -o results.json
```

Note: This writes a JSON array to `results.json`. When `--output` is used the CLI will not print the JSON array to stdout.

Expected file contents (`results.json`):

```json
["Product A", "Product B"]
```

2. Save NDJSON (one JSON object per line)

Sample input & command (schema that emits objects):

```sh
echo '<div class="product"><div class="product"><h2>Product A</h2></div><div class="product"><h2>Product B</h2></div></div>' \
  | res-scrapy -s '.product' --schema '{"fields": {"title": {"selector": "h2","type": "text"}}}' -o results.ndjson -f ndjson
```

Note: `--format ndjson` only affects file output when `--output` is present. NDJSON writes one JSON object per line (no surrounding array). NDJSON requires the extraction result to be an array of objects; requesting NDJSON for a non-array result will produce a WriteError.

Example `results.ndjson` contents:

```json
{"title":"Product A"}
{"title":"Product B"}
```

Small note: If you pass `--format` without `--output`, the flag is ignored and the CLI still prints the JSON array to stdout.

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

## 5. Multi-Page URL Fetching

Fetch data from paginated websites without piping each page through stdin. URL templates automatically expand `{start..end}` into multiple URLs, fetch them concurrently, and extract from every page.

> [!Note] When using `--url`, stdin is not read. An extraction flag (`-s`, `-p`, or `-t`) is required. Output automatically switches to NDJSON on stdout (one result per page). Use `--output` + `--format json` to get a single merged JSON array instead.

### 1. Basic range `{start..end}`

Scrape [books.toscrape](https://books.toscrape.com) — 50 pages (1 to 50):

```sh
res-scrapy \
  --url 'https://books.toscrape.com/catalogue/page-{1..50}.html' \
  -s 'h3' -e text -m
```

Each page yields a row of results. Stdout (NDJSON):

```json
{"url":"https://books.toscrape.com/catalogue/page-1.html","result":["A Light in the Attic","Tipping the Velvet",...]}
{"url":"https://books.toscrape.com/catalogue/page-2.html","result":["Sapiens","The Grand Design",...]}
```

### 2. Range with step `{start..end..step}`

Fetch every 10th page:

```sh
res-scrapy \
  --url 'https://site.com/articles?page={0..100..10}' \
  -s 'h2' -e text -m
```

### 3. Zero-padded ranges `{001..050}`

When URLs use zero-padded numbers (e.g. `page-001.html`):

```sh
res-scrapy \
  --url 'https://site.com/page-{001..050}.html' \
  -s '.product' -e text -m
```

This expands to `page-001.html`, `page-002.html`, … `page-050.html`.

### 4. Concurrency control & Rate Limiting

Use `-j` / `--concurrency` to control how many pages are fetched simultaneously (default is 5, max is 20).
Use `--delay` to ensure a minimum gap (in milliseconds) between request starts, avoiding rate limits.

```sh
# Faster scraping (20 concurrent fetches)
res-scrapy -u 'https://site.com/page-{1..100}.html' -s 'h2' -e text -m -j 20

# Polite scraping (5 concurrent, but force 500ms between each request start)
res-scrapy -u 'https://site.com/page-{1..100}.html' -s 'h2' -e text -m --delay 500
```

### 5. Save merged results to a file

Combine all pages into a single JSON file:

```sh
res-scrapy \
  --url 'https://books.toscrape.com/catalogue/page-{1..50}.html' \
  -s 'h3' -e text -m \
  --output all-titles.json
```

File output defaults to JSON (a single merged array). Use `--format ndjson` to stream one page-result per line instead.

### 6. Error behavior

- Failed pages are **skipped** (not retried after 3 attempts with backoff)
- A report of failed URLs is printed to **stderr**
- Exit code is **0** if any page succeeded, **1** if all failed

### 8. Custom Headers & Auth

You can pass custom headers or cookies for protected sites:

```sh
res-scrapy \
  --url 'https://site.com/api/data-{1..5}' \
  --header 'Authorization: Bearer token123' \
  --cookie 'session_id=abc456' \
  -s '.item' -e text -m
```

Scrape all 1000 book titles from books.toscrape.com (50 pages × 20 books):

```sh
res-scrapy \
  --url 'https://books.toscrape.com/catalogue/page-{1..50}.html' \
  -s 'h3' -e text -m -j 20 \
  --output books.json
```

This fetches 50 pages concurrently (up to 20 at a time), extracts every `<h3>` text, and writes one merged JSON array with 1000 titles to `books.json`.

---

## 6. Advanced Patterns & Error Handling

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

```sh
res-scrapy --schemaPath examples/schema-product.json < examples/sample.html
```

3. Debugging tips

- When a schema produces no rows, check if `config.rowSelector` is set correctly. Without `rowSelector` the extractor zips fields by index (legacy behavior).
- Use `--mode -s '<selector>' -e attr:name` to quickly probe which elements match and what attributes they expose.
