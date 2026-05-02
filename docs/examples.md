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

Sample first page HTML from books.toscrape.com:

```html
<article class="product_pod">
  <div class="image_container">
    <a href="a-light-in-the-attic_1000/index.html">
      <img src="../media/cache/2c/da/2cdad67c44b002e7ead0cc35693c0e8b.jpg" alt="A Light in the Attic">
    </a>
  </div>
  <p class="star-rating Three">
    <i class="icon-star"></i><i class="icon-star"></i><i class="icon-star"></i>...
  </p>
  <h3><a href="a-light-in-the-attic_1000/index.html" title="A Light in the Attic">A Light in the ...</a></h3>
  <div class="product_price">
    <p class="price_color">£51.77</p>
    <p class="instock availability"><i class="icon-ok"></i>In stock</p>
  </div>
</article>
```

Command (single page, extract all `<h3>` text):

```sh
res-scrapy --url 'https://books.toscrape.com/catalogue/page-1.html' -s 'h3' -e text -m
```

Expected output (NDJSON):

```json
{"url":"https://books.toscrape.com/catalogue/page-1.html","result":["A Light in the ...","Tipping the Velvet","Soumission","Sharp Objects","Sapiens: A Brief History of Humankind","The Requiem Red","The Dirty Little Secrets of Getting Your Dream Job","The Coming Woman: A Novel Based on the Life of the Infamous Feminist, Victoria Woodhull","The Boys in the Boat: Nine Americans and Their Epic Quest for Gold at the 1936 Berlin Olympics","The Black Maria","Starving Hearts (Triangular Trade Trilogy, #1)","Shakespeare\u0027s Sonnets","Set Me Free","Scott Pilgrim\u0027s Precious Little Life (Scott Pilgrim #1)","Rip it Up and Start Again","Our Band Could Be Your Life: Scenes from the American Indie Underground, 1981-1991","Olio","Mesaerion: The Best Science Fiction Stories 1800-1849",...]}
```

To get full titles (not truncated), use `title` attribute:

```sh
res-scrapy --url 'https://books.toscrape.com/catalogue/page-1.html' -s 'h3 a' -e 'attr:title' -m
```

Expected output:

```json
{"url":"https://books.toscrape.com/catalogue/page-1.html","result":["A Light in the Attic","Tipping the Velvet","Soumission","Sharp Objects","Sapiens: A Brief History of Humankind","The Requiem Red","The Dirty Little Secrets of Getting Your Dream Job","The Coming Woman: A Novel Based on the Life of the Infamous Feminist, Victoria Woodhull","The Boys in the Boat: Nine Americans and Their Epic Quest for Gold at the 1936 Berlin Olympics","The Black Maria","Starving Hearts (Triangular Trade Trilogy, #1)","Shakespeare\u0027s Sonnets","Set Me Free","Scott Pilgrim\u0027s Precious Little Life (Scott Pilgrim #1)","Rip it Up and Start Again","Our Band Could Be Your Life: Scenes from the American Indie Underground, 1981-1991","Olio","Mesaerion: The Best Science Fiction Stories 1800-1849",...]}
```

### 2. Extract prices (converting currency to number)

```sh
res-scrapy --url 'https://books.toscrape.com/catalogue/page-1.html' -s '.price_color' -e text -m
```

Expected output:

```json
{"url":"https://books.toscrape.com/catalogue/page-1.html","result":["£51.77","£53.74","£50.10","£47.82","£54.23","£22.65","£33.34","£17.93","£22.60","£52.15","£13.99","£20.66","£17.46","£52.29","£35.02","£57.25","£23.88","£37.59",...]}
```

### 3. Extract links (absolute URLs)

```sh
res-scrapy --url 'https://books.toscrape.com/catalogue/page-1.html' -s 'h3 a' -e 'attr:href' -m
```

Expected output:

```json
{"url":"https://books.toscrape.com/catalogue/page-1.html","result":["a-light-in-the-attic_1000/index.html","tipping-the-velvet_999/index.html","soumission_998/index.html",...]}
```

Note: Links are relative. For absolute URLs, prepend the base URL in post-processing.

### 4. Schema-driven structured extraction

Extract multiple fields per book (title, price, rating, stock, image, link):

```sh
res-scrapy \
  --url 'https://books.toscrape.com/catalogue/page-1.html' \
  --schema '{"config":{"rowSelector":".product_pod"},"fields":{"title":{"selector":"h3 a","type":"text","attribute":"title"},"price":{"selector":".price_color","type":"text"},"rating":{"selector":".star-rating","type":"attribute","attribute":"class"},"stock":{"selector":".instock","type":"text"},"image":{"selector":".image_container img","type":"attribute","attribute":"src"},"link":{"selector":"h3 a","type":"attribute","attribute":"href"}}}' \
  -m
```

Expected output:

```json
{"url":"https://books.toscrape.com/catalogue/page-1.html","result":[{"title":"A Light in the Attic","price":"£51.77","rating":"star-rating Three","stock":"In stock","image":"../media/cache/2c/da/2cdad67c44b002e7ead0cc35693c0e8b.jpg","link":"a-light-in-the-attic_1000/index.html"},{"title":"Tipping the Velvet","price":"£53.74","rating":"star-rating One","stock":"In stock","image":"../media/cache/26/0c/260c6ae16bce31c8f8c95daddd9f4a1c.jpg","link":"tipping-the-velvet_999/index.html"},...]}
```

### 5. Convert price to number with `stripNonNumeric`

Use the `number` type with `stripNonNumeric: true` to convert "£51.77" → 51.77:

```sh
res-scrapy \
  --url 'https://books.toscrape.com/catalogue/page-1.html' \
  --schema '{"config":{"rowSelector":".product_pod"},"fields":{"title":{"selector":"h3 a","type":"text","attribute":"title"},"price":{"selector":".price_color","type":"number","numberOptions":{"stripNonNumeric":true}}}' \
  -m
```

Expected output:

```json
{"url":"https://books.toscrape.com/catalogue/page-1.html","result":[{"title":"A Light in the Attic","price":51.77},{"title":"Tipping the Velvet","price":53.74},{"title":"Soumission","price":50.1},...]}
```

### 6. Parse rating from CSS class

The rating is stored in the class attribute (e.g., "star-rating Three"). Extract the word:

```sh
res-scrapy \
  --url 'https://books.toscrape.com/catalogue/page-1.html' \
  --schema '{"config":{"rowSelector":".product_pod"},"fields":{"title":{"selector":"h3 a","type":"text","attribute":"title"},"rating":{"selector":".star-rating","type":"text"}}}' \
  -m
```

Expected output:

```json
{"url":"https://books.toscrape.com/catalogue/page-1.html","result":[{"title":"A Light in the Attic","rating":"Three"},{"title":"Tipping the Velvet","rating":"One"},{"title":"Sapiens: A Brief History of Humankind","rating":"Five"},...]}
```

### 7. Range with step `{start..end..step}`

Fetch every 10th page:

```sh
res-scrapy \
  --url 'https://site.com/articles?page={0..100..10}' \
  -s 'h2' -e text -m
```

### 8. Zero-padded ranges `{001..050}`

When URLs use zero-padded numbers (e.g. `page-001.html`):

```sh
res-scrapy \
  --url 'https://site.com/page-{001..050}.html' \
  -s '.product' -e text -m
```

This expands to `page-001.html`, `page-002.html`, … `page-050.html`.

### 9. Concurrency control & Rate Limiting

Use `-j` / `--concurrency` to control how many pages are fetched simultaneously (default is 5, max is 20).
Use `--delay` to ensure a minimum gap (in milliseconds) between request starts, avoiding rate limits.

```sh
# Faster scraping (20 concurrent fetches)
res-scrapy -u 'https://site.com/page-{1..100}.html' -s 'h2' -e text -m -j 20

# Polite scraping (5 concurrent, but force 500ms between each request start)
res-scrapy -u 'https://site.com/page-{1..100}.html' -s 'h2' -e text -m --delay 500
```

### 10. Save merged results to a file

Combine all pages into a single JSON file:

```sh
res-scrapy \
  --url 'https://books.toscrape.com/catalogue/page-{1..50}.html' \
  -s 'h3' -e text -m \
  --output all-titles.json
```

File output defaults to JSON (a single merged array). Use `--format ndjson` to stream one page-result per line instead.

### 11. Error behavior

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
