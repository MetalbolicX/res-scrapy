# Schema Reference

Complete reference for the res-scrapy schema system. This guide covers everything you need to write effective schemas for structured HTML extraction.

> **Prerequisites**: You should understand basic CLI usage. See [Getting Started](/getting-started) and [Examples](/examples) first if you're new to res-scrapy.

---

## CLI Flags Overview

Two main modes support structured extraction:

| Flag           | Short | Description                         |
| -------------- | ----- | ----------------------------------- |
| `--schema`     | `-c`  | Pass a schema as inline JSON string |
| `--schemaPath` | `-p`  | Path to a `.json` schema file       |
| `--table`      | `-t`  | Extract an HTML table as JSON array |

**Basic usage patterns:**

```bash
# Inline schema (good for quick tests)
echo '<html>...</html>' | res-scrapy --schema '{"fields": {...}}'

# Schema from file (recommended for production)
res-scrapy --schemaPath product-schema.json < page.html

# Table extraction
res-scrapy --table < page-with-table.html
```

---

## Schema Mode (`--schema` / `--schemaPath`)

Schema mode lets you declaratively extract structured data by defining fields with selectors and types. Each field maps HTML elements to typed values in your output JSON.

### Schema Structure

A schema is a JSON object with this structure:

```json
{
  "name": "Product Schema",
  "description": "Extract product information",
  "config": {
    /* global settings */
  },
  "fields": {
    /* field definitions */
  }
}
```

### Complete Example

Here's a real-world product extraction schema:

```json
{
  "name": "E-commerce Product Schema",
  "config": {
    "rowSelector": ".product-card",
    "ignoreErrors": false
  },
  "fields": {
    "name": {
      "selector": "h2",
      "type": "text",
      "required": true
    },
    "price": {
      "selector": ".price",
      "type": "number",
      "numberOptions": {
        "stripNonNumeric": true,
        "pattern": "\\$?([0-9,\\.]+)"
      }
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
        "trueValues": ["in stock", "available"]
      }
    }
  }
}
```

**Sample HTML:**

```html
<article class="product-card">
  <h2>Premium Widget</h2>
  <span class="price">$49.99</span>
  <img data-src="https://cdn.example.com/widget.jpg" src="/fallback.jpg" />
  <span class="stock-status">In Stock</span>
</article>
```

**Command:**

```bash
echo '<article class="product-card">...</article>' | \
  res-scrapy --schemaPath product-schema.json
```

**Output:**

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

## Table Mode (`--table`)

Table extraction converts HTML `<table>` elements into JSON arrays. It's the fastest way to extract tabular data without writing a schema.

### Basic Table Extraction

**Sample HTML:**

```html
<table>
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

**Command:**

```bash
echo '<table>...</table>' | res-scrapy --table
```

**Output:**

```json
[
  { "Product": "Widget A", "Price": "$9.99", "In Stock": "Yes" },
  { "Product": "Widget B", "Price": "$14.99", "In Stock": "No" }
]
```

### Targeting a Specific Table

When a page has multiple tables, use `--selector` to target one:

```bash
# Extract the table with id="products"
cat page.html | res-scrapy --table --selector '#products'
```

### Table Extraction Rules

1. **Headers become keys**: The first row (in `<thead>` or first `<tr>`) determines object keys
2. **All values are strings**: No type conversion happens in table mode
3. **Empty cells become empty strings**: `""` not `null`
4. **Rowspan/colspan**: Handled by duplicating values across spanned cells

### When to Use Table Mode vs Schema Mode

<!-- tabs:start -->

#### **Use Table Mode when...**

- Data is already in a `<table>` element
- You need raw string values (no type conversion)
- Quick one-off extraction is sufficient
- You don't need to transform the data

**Example:** Extracting a product comparison table

```bash
curl -s 'https://example.com/comparison' | res-scrapy -t -s '#comparison-table'
```

#### **Use Schema Mode when...**

- You need typed data (numbers, booleans, dates)
- Data is in divs/cards/grid layouts (not tables)
- You need to clean/transform values during extraction
- You're building a repeatable data pipeline

**Example:** Extracting e-commerce products with prices and availability

```json
{
  "config": { "rowSelector": ".product" },
  "fields": {
    "price": {
      "selector": ".price",
      "type": "number",
      "numberOptions": { "stripNonNumeric": true }
    },
    "available": { "selector": ".stock", "type": "boolean" }
  }
}
```

<!-- tabs:end -->

---

## Field Types

res-scrapy supports 10 field types. Each type has specific options for controlling extraction and transformation.

### 1. Text

Extracts text content from elements. Most common type for headlines, descriptions, and content.

**Options:**

| Option                | Type    | Default | Description                                           |
| --------------------- | ------- | ------- | ----------------------------------------------------- |
| `trim`                | boolean | `true`  | Remove leading/trailing whitespace                    |
| `normalizeWhitespace` | boolean | `false` | Collapse multiple spaces/newlines                     |
| `lowercase`           | boolean | `false` | Convert to lowercase                                  |
| `uppercase`           | boolean | `false` | Convert to uppercase                                  |
| `pattern`             | string  | —       | Regex pattern to extract (uses capture group 1)       |
| `join`                | string  | —       | When `multiple: true`, join array with this separator |

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

**HTML:**

```html
<h1>Breaking News Story</h1>
<span class="tag">Tech</span>
<span class="tag">AI</span>
```

**Output:**

```json
{ "title": "Breaking News Story", "tags": "Tech, AI" }
```

---

### 2. Attribute

Extracts HTML attribute values. Essential for links (`href`), images (`src`), and data attributes.

**Options:**

| Option       | Type     | Default           | Description                                     |
| ------------ | -------- | ----------------- | ----------------------------------------------- |
| `attribute`  | string   | —                 | Single attribute name (legacy)                  |
| `attributes` | string[] | —                 | Array of attribute names to try                 |
| `attrMode`   | string   | `"firstNonEmpty"` | `"first"`, `"firstNonEmpty"`, `"all"`, `"join"` |
| `attrJoin`   | string   | —                 | Separator when `attrMode: "join"`               |

**Modes:**

<!-- tabs:start -->

#### **firstNonEmpty (default)**

Returns the first non-empty attribute value. Perfect for lazy-loaded images.

```json
{
  "imageUrl": {
    "selector": "img",
    "type": "attribute",
    "attributes": ["data-lazy", "data-src", "src"],
    "attrMode": "firstNonEmpty"
  }
}
```

**HTML:**

```html
<img
  data-lazy=""
  data-src="https://cdn.example.com/img.jpg"
  src="/fallback.jpg"
/>
```

**Output:**

```json
{ "imageUrl": "https://cdn.example.com/img.jpg" }
```

#### **all**

Returns an object with all requested attributes.

```json
{
  "linkAttrs": {
    "selector": "a",
    "type": "attribute",
    "attributes": ["href", "title", "rel"],
    "attrMode": "all"
  }
}
```

**HTML:**

```html
<a href="/page" title="Click here" rel="noopener">Link</a>
```

**Output:**

```json
{ "linkAttrs": { "href": "/page", "title": "Click here", "rel": "noopener" } }
```

#### **join**

Concatenates multiple attributes with a separator.

```json
{
  "classes": {
    "selector": "div",
    "type": "attribute",
    "attributes": ["class", "data-class"],
    "attrMode": "join",
    "attrJoin": " "
  }
}
```

**HTML:**

```html
<div class="card" data-class="highlighted"></div>
```

**Output:**

```json
{ "classes": "card highlighted" }
```

<!-- tabs:end -->

---

### 3. HTML

Extracts raw HTML markup. Useful when you need to preserve formatting or extract element structures.

**Options:**

| Option         | Type    | Default   | Description            |
| -------------- | ------- | --------- | ---------------------- |
| `mode`         | string  | `"inner"` | `"inner"` or `"outer"` |
| `stripScripts` | boolean | `false`   | Remove `<script>` tags |
| `stripStyles`  | boolean | `false`   | Remove `<style>` tags  |

**Modes:**

<!-- tabs:start -->

#### **inner (default)**

Extracts the inner HTML (content only).

```json
{
  "content": {
    "selector": ".article",
    "type": "html",
    "htmlOptions": {
      "mode": "inner",
      "stripScripts": true
    }
  }
}
```

**HTML:**

```html
<div class="article">
  <p>Paragraph</p>
  <script>
    alert("xss");
  </script>
</div>
```

**Output:**

```json
{ "content": "<p>Paragraph</p>" }
```

#### **outer**

Extracts the outer HTML (includes the element itself).

```json
{
  "card": {
    "selector": ".card",
    "type": "html",
    "htmlOptions": { "mode": "outer" }
  }
}
```

**HTML:**

```html
<div class="card" data-id="123"><p>Content</p></div>
```

**Output:**

```json
{ "card": "<div class=\"card\" data-id=\"123\"><p>Content</p></div>" }
```

<!-- tabs:end -->

---

### 4. Number

Parses numeric values from text. Handles currency, percentages, and locale-specific formats.

**Options:**

| Option               | Type    | Default  | Description                                    |
| -------------------- | ------- | -------- | ---------------------------------------------- |
| `stripNonNumeric`    | boolean | `true`   | Remove non-digit chars except `.` and `-`      |
| `pattern`            | string  | —        | Regex to extract number (uses capture group 1) |
| `thousandsSeparator` | string  | `","`    | Character to strip as thousands separator      |
| `decimalSeparator`   | string  | `"."`    | Decimal point character                        |
| `locale`             | string  | —        | Locale-aware parsing (e.g., `"de-DE"`)         |
| `precision`          | number  | —        | Round to N decimal places                      |
| `onError`            | string  | `"null"` | `"null"`, `"text"`, `"default"`, or `"error"`  |

**Parsing priority:**

1. If `pattern` is provided, extract capture group
2. If `stripNonNumeric: true`, remove currency/formatting
3. Handle separators and locale
4. Parse with `parseFloat`
5. Apply `precision` if specified

**Examples:**

<!-- tabs:start -->

#### **Currency**

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

**HTML:**

```html
<span class="price">$1,234.56</span>
```

**Output:**

```json
{ "price": 1234.56 }
```

#### **Percentage**

```json
{
  "discount": {
    "selector": ".discount",
    "type": "number",
    "numberOptions": {
      "pattern": "([0-9\\.]+)%"
    }
  }
}
```

**HTML:**

```html
<span class="discount">25.5% OFF</span>
```

**Output:**

```json
{ "discount": 25.5 }
```

#### **European Format**

```json
{
  "price": {
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

**HTML:**

```html
<span class="preis">1.234,56 €</span>
```

**Output:**

```json
{ "price": 1234.56 }
```

<!-- tabs:end -->

---

### 5. Boolean

Extracts and interprets boolean values from text, element presence, or attributes.

**Options:**

| Option        | Type     | Default                | Description                                  |
| ------------- | -------- | ---------------------- | -------------------------------------------- |
| `mode`        | string   | `"mapping"`            | `"mapping"`, `"presence"`, or `"attribute"`  |
| `trueValues`  | string[] | `["true", "yes", "1"]` | Strings that map to `true`                   |
| `falseValues` | string[] | `["false", "no", "0"]` | Strings that map to `false`                  |
| `attribute`   | string   | —                      | For `mode: "attribute"`, which attr to check |
| `pattern`     | string   | —                      | Regex pattern (match = true)                 |
| `onUnknown`   | string   | `"false"`              | `"false"`, `"null"`, or `"error"`            |

**Modes:**

<!-- tabs:start -->

#### **mapping (default)**

Compares text content against true/false value lists.

```json
{
  "inStock": {
    "selector": ".stock-status",
    "type": "boolean",
    "booleanOptions": {
      "mode": "mapping",
      "trueValues": ["in stock", "available", "yes", "✓"],
      "falseValues": ["out of stock", "unavailable", "no", "✗"]
    }
  }
}
```

**HTML:**

```html
<span class="stock-status">In Stock</span>
```

**Output:**

```json
{ "inStock": true }
```

#### **presence**

Returns `true` if the selector matches any element, `false` otherwise. Great for badges and labels.

```json
{
  "hasDiscount": {
    "selector": ".discount-badge",
    "type": "boolean",
    "booleanOptions": { "mode": "presence" }
  }
}
```

**HTML:**

```html
<!-- With badge -->
<div class="product">
  <span class="discount-badge">-20%</span>
</div>

<!-- Without badge -->
<div class="product">
  <!-- No badge -->
</div>
```

**Output:**

```json
// First product
{"hasDiscount": true}

// Second product
{"hasDiscount": false}
```

#### **attribute**

Checks if an attribute exists and has a truthy value.

```json
{
  "isChecked": {
    "selector": "input[type=checkbox]",
    "type": "boolean",
    "booleanOptions": {
      "mode": "attribute",
      "attribute": "checked"
    }
  }
}
```

**HTML:**

```html
<input type="checkbox" checked />
```

**Output:**

```json
{ "isChecked": true }
```

<!-- tabs:end -->

---

### 6. DateTime

Parses dates from various formats and converts to standardized output.

**Options:**

| Option         | Type     | Default     | Description                                         |
| -------------- | -------- | ----------- | --------------------------------------------------- |
| `formats`      | string[] | —           | Parsing format patterns (tried in order)            |
| `timezone`     | string   | `"UTC"`     | IANA timezone for output                            |
| `output`       | string   | `"iso8601"` | `"iso8601"`, `"epoch"`, `"epochMillis"`, `"custom"` |
| `outputFormat` | string   | —           | Custom format when `output: "custom"`               |
| `strict`       | boolean  | `false`     | Require strict parsing                              |
| `locale`       | string   | —           | Locale for month/day names                          |
| `source`       | string   | `"text"`    | `"text"` or `"attribute"`                           |
| `attribute`    | string   | —           | When `source: "attribute"`                          |

**Format tokens:**

| Token  | Meaning       |
| ------ | ------------- |
| `yyyy` | 4-digit year  |
| `yy`   | 2-digit year  |
| `MM`   | 2-digit month |
| `dd`   | 2-digit day   |
| `HH`   | 24-hour       |
| `mm`   | Minutes       |
| `ss`   | Seconds       |

**Special format values:** `"ISO"`, `"epoch"`, `"epochMillis"`

**Examples:**

<!-- tabs:start -->

#### **ISO from attribute**

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

**HTML:**

```html
<time datetime="2024-03-15T10:30:00Z">March 15, 2024</time>
```

**Output:**

```json
{ "publishedAt": "2024-03-15T10:30:00.000Z" }
```

#### **Multiple human formats**

```json
{
  "date": {
    "selector": ".date",
    "type": "datetime",
    "dateOptions": {
      "formats": ["MMMM dd, yyyy", "MM/dd/yyyy", "yyyy-MM-dd"],
      "output": "iso8601"
    }
  }
}
```

**HTML:**

```html
<span class="date">March 15, 2024</span>
<!-- or -->
<span class="date">03/15/2024</span>
```

**Output:**

```json
{ "date": "2024-03-15T00:00:00.000Z" }
```

<!-- tabs:end -->

---

### 7. Count

Returns the number of elements matching a selector. Useful for "number of reviews", "image count", etc.

**Options:**

| Option | Type   | Description                                 |
| ------ | ------ | ------------------------------------------- |
| `min`  | number | Minimum expected count (validation warning) |
| `max`  | number | Maximum expected count (validation warning) |

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

**HTML:**

```html
<div class="reviews">
  <div class="review">Review 1</div>
  <div class="review">Review 2</div>
  <div class="review">Review 3</div>
</div>
<img class="gallery" src="1.jpg" />
<img class="gallery" src="2.jpg" />
```

**Output:**

```json
{ "reviewCount": 3, "imageCount": 2 }
```

---

### 8. URL

Extracts and normalizes URLs. Resolves relative URLs and validates format.

**Options:**

| Option       | Type    | Default            | Description                          |
| ------------ | ------- | ------------------ | ------------------------------------ |
| `base`       | string  | —                  | Base URL for resolving relative URLs |
| `resolve`    | boolean | `true`             | Resolve relative to base             |
| `validate`   | boolean | `true`             | Validate URL format                  |
| `protocol`   | string  | `"any"`            | `"http"`, `"https"`, or `"any"`      |
| `stripQuery` | boolean | `false`            | Remove query string                  |
| `stripHash`  | boolean | `false`            | Remove fragment                      |
| `attribute`  | string  | `"href"` / `"src"` | Attribute to extract                 |

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

**HTML:**

```html
<base href="https://example.com" />
<a class="product-link" href="/product/123">Product</a>
<link rel="canonical" href="https://example.com/page?id=123" />
```

**Output:**

```json
{
  "productUrl": "https://example.com/product/123",
  "canonicalUrl": "https://example.com/page"
}
```

---

### 9. JSON

Extracts and parses embedded JSON content. Perfect for JSON-LD structured data or data attributes.

**Options:**

| Option      | Type    | Default  | Description                      |
| ----------- | ------- | -------- | -------------------------------- |
| `source`    | string  | `"text"` | `"text"` or `"attribute"`        |
| `attribute` | string  | —        | When `source: "attribute"`       |
| `path`      | string  | —        | JSONPath to extract subset       |
| `validate`  | boolean | `true`   | Validate JSON format             |
| `onError`   | string  | `"null"` | `"null"`, `"text"`, or `"error"` |

**Examples:**

<!-- tabs:start -->

#### **JSON-LD (structured data)**

```json
{
  "productData": {
    "selector": "script[type='application/ld+json']",
    "type": "json",
    "jsonOptions": {
      "path": "$.offers"
    }
  }
}
```

**HTML:**

```html
<script type="application/ld+json">
  {
    "@type": "Product",
    "name": "Widget",
    "offers": {
      "price": "29.99",
      "priceCurrency": "USD"
    }
  }
</script>
```

**Output:**

```json
{ "productData": { "price": "29.99", "priceCurrency": "USD" } }
```

#### **Data attribute JSON**

```json
{
  "config": {
    "selector": ".widget",
    "type": "json",
    "jsonOptions": {
      "source": "attribute",
      "attribute": "data-config"
    }
  }
}
```

**HTML:**

```html
<div class="widget" data-config='{"theme": "dark", "autoplay": true}'></div>
```

**Output:**

```json
{ "config": { "theme": "dark", "autoplay": true } }
```

<!-- tabs:end -->

---

### 10. List

Collects multiple matches into a typed array. Similar to `multiple: true` but with more control over item types.

**Options:**

| Option      | Type    | Default  | Description                                   |
| ----------- | ------- | -------- | --------------------------------------------- |
| `itemType`  | string  | `"text"` | `"text"`, `"html"`, `"attribute"`, or `"url"` |
| `attribute` | string  | —        | When `itemType: "attribute"`                  |
| `unique`    | boolean | `false`  | Remove duplicates                             |
| `filter`    | string  | —        | Regex pattern to filter items                 |
| `limit`     | number  | —        | Max items to collect                          |
| `join`      | string  | —        | Join into string instead of array             |

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

**HTML:**

```html
<span class="category">Tech</span>
<span class="category">AI</span>
<span class="category">Tech</span>
<img src="1.jpg" />
<img src="2.jpg" />
<img src="3.jpg" />
```

**Output:**

```json
{
  "categories": ["Tech", "AI"],
  "imageUrls": ["1.jpg", "2.jpg", "3.jpg"]
}
```

---

## Global Config

The `config` section sets defaults that apply to all fields in the schema.

### Config Options

| Option         | Type    | Default         | Description                         |
| -------------- | ------- | --------------- | ----------------------------------- |
| `rowSelector`  | string  | —               | CSS selector for row containers     |
| `ignoreErrors` | boolean | `false`         | Continue extraction on field errors |
| `limit`        | number  | `0` (unlimited) | Max rows to extract                 |
| `defaults`     | object  | —               | Default options per type            |
| `output`       | object  | —               | Output formatting options           |

### Row Selector (Most Important)

`rowSelector` changes how extraction works from "zip by index" to "row-based":

<!-- tabs:start -->

#### **Without rowSelector (zip mode)**

```json
{
  "fields": {
    "name": { "selector": ".product h2", "type": "text" },
    "price": { "selector": ".product .price", "type": "number" }
  }
}
```

**Behavior:**

- Each selector runs against the entire document
- Rows created by zipping results by index
- Row count = length of first field's results
- ⚠️ Fragile if fields have different counts

#### **With rowSelector (recommended)**

```json
{
  "config": { "rowSelector": ".product-card" },
  "fields": {
    "name": { "selector": "h2", "type": "text" },
    "price": { "selector": ".price", "type": "number" }
  }
}
```

**Behavior:**

- `querySelectorAll(rowSelector)` finds row elements
- Each field selector runs **relative to** its row
- Row count = number of elements matching `rowSelector`
- ✅ More reliable and intuitive

<!-- tabs:end -->

### Ignore Errors

When `ignoreErrors: true`, field extraction failures don't abort the entire extraction:

```json
{
  "config": {
    "ignoreErrors": true
  },
  "fields": {
    "price": {
      "selector": ".price",
      "type": "number",
      "default": null
    }
  }
}
```

**HTML:**

```html
<div class="product">
  <span class="price">invalid</span>
  <!-- parse fails -->
</div>
<div class="product">
  <!-- No price element -->
</div>
```

**Output:**

```json
[{ "price": null }, { "price": null }]
```

Without `ignoreErrors`, either case would cause the CLI to exit with an error.

### Type Defaults

Set default options for all fields of a given type:

```json
{
  "config": {
    "defaults": {
      "number": {
        "stripNonNumeric": true,
        "precision": 2
      },
      "boolean": {
        "trueValues": ["yes", "available"],
        "falseValues": ["no", "unavailable"]
      }
    }
  },
  "fields": {
    "price1": { "selector": ".price1", "type": "number" },
    "price2": { "selector": ".price2", "type": "number" },
    "inStock": { "selector": ".stock", "type": "boolean" }
  }
}
```

Field-level options override global defaults.

---

## Shared Field Options

These options work with any field type:

| Option     | Type    | Default      | Description                                        |
| ---------- | ------- | ------------ | -------------------------------------------------- |
| `selector` | string  | **required** | CSS selector to match elements                     |
| `type`     | string  | **required** | Field type (text, number, boolean, etc.)           |
| `required` | boolean | `false`      | Abort if element not found (unless `ignoreErrors`) |
| `default`  | any     | —            | Value when element not found or parse fails        |
| `multiple` | boolean | `false`      | Return array of all matches                        |

### Multiple Mode

When `multiple: true`, the field returns an array instead of a single value:

```json
{
  "tags": {
    "selector": ".tag",
    "type": "text",
    "multiple": true
  }
}
```

**HTML:**

```html
<span class="tag">Red</span>
<span class="tag">Blue</span>
<span class="tag">Green</span>
```

**Output:**

```json
{ "tags": ["Red", "Blue", "Green"] }
```

**Note:** For typed arrays with more control, use `type: "list"` instead.

---

## Error Handling

### Field-Level Errors

When a field extraction fails, behavior depends on configuration:

**1. Required field missing:**

```json
{
  "fields": {
    "title": {
      "selector": "h1",
      "type": "text",
      "required": true
    }
  }
}
```

- `config.ignoreErrors: false` → CLI exits with error
- `config.ignoreErrors: true` → Uses `default` or `null`

**2. Parse error (invalid number, date, etc.):**

```json
{
  "fields": {
    "price": {
      "selector": ".price",
      "type": "number",
      "numberOptions": {
        "onError": "null"
      }
    }
  }
}
```

Follows the type's `onError` policy:

- `"null"` → Returns `null`
- `"text"` → Returns original text
- `"default"` → Uses field's `default` value
- `"error"` → Throws error (unless `ignoreErrors`)

**3. Using default values:**

```json
{
  "config": { "ignoreErrors": true },
  "fields": {
    "price": {
      "selector": ".price",
      "type": "number",
      "default": 0
    }
  }
}
```

When extraction fails: `{"price": 0}`

### Schema-Level Errors

These errors always cause CLI exit (cannot be ignored):

| Error              | Cause                         |
| ------------------ | ----------------------------- |
| `InvalidJson`      | Schema file is not valid JSON |
| `MissingFields`    | No `fields` key in schema     |
| `InvalidFieldType` | Unknown field type specified  |
| `InvalidSelector`  | CSS selector syntax error     |

---

## Migration from v1.0 to v2.0

If you have existing v1.0 schemas, here are the key changes:

### Breaking Changes

**1. Number parsing is smarter by default:**

```json
// v1.0: "$29.99" → null (failed to parse)
// v2.0: "$29.99" → 29.99 (strips non-numeric by default)
```

**2. Boolean mapping is more flexible:**

```json
// v1.0: Only "true" / "false" strings work
// v2.0: Configurable trueValues/falseValues
{
  "inStock": {
    "type": "boolean",
    "booleanOptions": {
      "trueValues": ["in stock", "available"]
    }
  }
}
```

**3. Attribute type supports arrays:**

```json
// v1.0 (still works)
{"type": "attribute", "attribute": "href"}

// v2.0 (recommended for lazy-loaded images)
{"type": "attribute", "attributes": ["data-src", "src"]}
```

### New Features in v2.0

- **New field types**: `datetime`, `url`, `count`, `json`, `list`
- **Row-based extraction**: `config.rowSelector` for reliable repeated data
- **Type defaults**: `config.defaults` to reduce repetition
- **Better options**: Per-type configuration objects

### Backwards Compatibility

- Old `attribute` (singular) syntax still supported
- Legacy zip-by-first-field when `rowSelector` not specified
- Array format for fields still supported

---

## Quick Reference Table

| Type        | What it extracts | Key options                               | Common use case             |
| ----------- | ---------------- | ----------------------------------------- | --------------------------- |
| `text`      | Text content     | `trim`, `pattern`, `join`                 | Headlines, descriptions     |
| `attribute` | HTML attributes  | `attributes[]`, `attrMode`                | Links, images, data attrs   |
| `html`      | Raw markup       | `mode`, `stripScripts`                    | Preserving formatting       |
| `number`    | Numeric values   | `stripNonNumeric`, `pattern`, `precision` | Prices, ratings, counts     |
| `boolean`   | True/false       | `mode`, `trueValues`                      | Availability, status flags  |
| `datetime`  | Dates/times      | `formats`, `output`                       | Published dates, events     |
| `count`     | Element count    | `min`, `max`                              | Review counts, image counts |
| `url`       | URLs             | `base`, `resolve`, `stripQuery`           | Links, canonical URLs       |
| `json`      | Embedded JSON    | `path`, `source`                          | JSON-LD, data attributes    |
| `list`      | Typed arrays     | `itemType`, `unique`, `limit`             | Tags, categories, galleries |

---

## Complete Example Schemas

### E-commerce Product Page

```json
{
  "name": "Product Schema",
  "config": {
    "rowSelector": ".product",
    "defaults": {
      "number": { "stripNonNumeric": true, "precision": 2 }
    }
  },
  "fields": {
    "name": { "selector": "h1", "type": "text", "required": true },
    "price": { "selector": ".price", "type": "number", "required": true },
    "originalPrice": {
      "selector": ".original-price",
      "type": "number",
      "default": null
    },
    "inStock": {
      "selector": ".stock",
      "type": "boolean",
      "booleanOptions": { "trueValues": ["in stock", "available"] }
    },
    "image": {
      "selector": "img",
      "type": "attribute",
      "attributes": ["data-src", "src"]
    },
    "category": {
      "selector": ".category",
      "type": "list",
      "listOptions": { "itemType": "text", "unique": true }
    }
  }
}
```

### Blog/News Article

```json
{
  "name": "Article Schema",
  "config": { "rowSelector": "article" },
  "fields": {
    "headline": { "selector": "h1", "type": "text", "required": true },
    "author": { "selector": ".author", "type": "text" },
    "publishedAt": {
      "selector": "time",
      "type": "datetime",
      "dateOptions": {
        "source": "attribute",
        "attribute": "datetime"
      }
    },
    "content": {
      "selector": ".article-body",
      "type": "html",
      "htmlOptions": { "stripScripts": true }
    },
    "tags": {
      "selector": ".tag",
      "type": "list",
      "listOptions": { "itemType": "text" }
    }
  }
}
```

### Job Listing

```json
{
  "name": "Job Schema",
  "config": { "rowSelector": ".job-card" },
  "fields": {
    "title": { "selector": "h2", "type": "text", "required": true },
    "company": { "selector": ".company", "type": "text" },
    "location": { "selector": ".location", "type": "text" },
    "salary": {
      "selector": ".salary",
      "type": "number",
      "numberOptions": { "pattern": "\\$?([0-9,]+)" }
    },
    "postedAt": {
      "selector": ".posted",
      "type": "datetime",
      "dateOptions": { "formats": ["MMMM dd, yyyy"] }
    },
    "url": {
      "selector": "a",
      "type": "url",
      "urlOptions": { "attribute": "href" }
    }
  }
}
```

---

## FAQ

**Q: Should I use `multiple: true` or `type: "list"`?**

A: Use `multiple: true` for simple text arrays. Use `type: "list"` when you need typed items (urls, attributes) or want to deduplicate/filter.

**Q: Why is my number field returning null?**

A: Check if `stripNonNumeric` is enabled (default in v2.0). If your format is unusual, use a `pattern` to extract the numeric part.

**Q: How do I extract from deeply nested structures?**

A: Use `config.rowSelector` to define the repeating container, then use simple selectors for fields within each row.

**Q: Can I combine table mode with schema mode?**

A: No, they're separate extraction modes. Use table mode for quick `<table>` extraction, schema mode for everything else.

**Q: Does res-scrapy work with JavaScript-rendered content?**

A: No, it only parses static HTML. For SPAs, use a headless browser (Puppeteer, Playwright) to render first, then pipe to res-scrapy.
