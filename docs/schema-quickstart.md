# Schema Quick Reference Card

One-page cheat sheet for res-scrapy schema v2.0 most common patterns.

---

## Basic Schema Structure

```json
{
  "name": "My Schema",
  "config": {
    "rowSelector": ".item",
    "ignoreErrors": false,
    "limit": 0
  },
  "fields": {
    "fieldName": {
      "selector": "css selector",
      "type": "text|attribute|html|number|boolean|datetime|url|count|json|list",
      "required": false,
      "default": null
    }
  }
}
```

---

## Field Types at a Glance

| Type        | Extracts           | Common Use                   |
| ----------- | ------------------ | ---------------------------- |
| `text`      | Text content       | Titles, descriptions, names  |
| `attribute` | Attribute value(s) | URLs, image sources, IDs     |
| `html`      | HTML markup        | Rich content, formatted text |
| `number`    | Parsed number      | Prices, counts, ratings      |
| `boolean`   | True/false         | Stock status, badges, flags  |
| `datetime`  | Parsed date        | Publish dates, timestamps    |
| `url`       | Resolved URL       | Links, canonical URLs        |
| `count`     | Element count      | Number of reviews, images    |
| `json`      | Parsed JSON        | Structured data, JSON-LD     |
| `list`      | Array of values    | Tags, categories, images     |

---

## 🔥 Most Common Patterns

### 1. Extract Price (with currency symbol)

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

**Input:** `$1,299.99` → **Output:** `1299.99`

---

### 2. Human-Readable Boolean

```json
{
  "inStock": {
    "selector": ".stock-status",
    "type": "boolean",
    "booleanOptions": {
      "trueValues": ["in stock", "available", "ships today"],
      "falseValues": ["out of stock", "sold out"]
    }
  }
}
```

**Input:** `In Stock` → **Output:** `true`

---

### 3. Check for Badge/Icon (Presence)

```json
{
  "isFeatured": {
    "selector": ".featured-badge",
    "type": "boolean",
    "booleanOptions": {
      "mode": "presence"
    }
  }
}
```

**Logic:** Element exists → `true`, missing → `false`

---

### 4. Lazy-Loaded Image (Fallback Attributes)

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

**Logic:** Try `data-lazy-src` first, then `data-src`, finally `src`

---

### 5. Parse Date/Time

```json
{
  "publishedAt": {
    "selector": "time",
    "type": "datetime",
    "dateOptions": {
      "source": "attribute",
      "attribute": "datetime",
      "formats": ["ISO", "yyyy-MM-dd", "MM/dd/yyyy"],
      "output": "iso8601"
    }
  }
}
```

---

### 6. Collect Multiple Items (Tags/Categories)

```json
{
  "tags": {
    "selector": ".tag",
    "type": "list",
    "listOptions": {
      "itemType": "text",
      "unique": true
    }
  }
}
```

**Output:** `["tag1", "tag2", "tag3"]`

---

### 7. Count Elements

```json
{
  "reviewCount": {
    "selector": ".review",
    "type": "count"
  }
}
```

---

### 8. Extract Percentage/Rating

```json
{
  "discount": {
    "selector": ".discount-badge",
    "type": "number",
    "numberOptions": {
      "pattern": "([0-9]+)%"
    }
  },
  "rating": {
    "selector": ".rating",
    "type": "number",
    "numberOptions": {
      "pattern": "([0-9\\.]+)\\s*out of",
      "precision": 1
    }
  }
}
```

---

### 9. Resolve Relative URLs

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

---

### 10. Extract JSON-LD / Structured Data

```json
{
  "structuredData": {
    "selector": "script[type='application/ld+json']",
    "type": "json",
    "jsonOptions": {
      "path": "$.offers.price"
    }
  }
}
```

---

## Row-Based Extraction

**Without `rowSelector` (old zip mode):**

```json
{
  "fields": {
    "name": { "selector": "h2", "type": "text" },
    "price": { "selector": ".price", "type": "number" }
  }
}
```

❌ Fragile: all `h2` and `.price` from entire page, zipped by index

**With `rowSelector` (recommended):**

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

✅ Robust: `h2` and `.price` extracted relative to each `.product-card`

---

## Options Summary

### Text Options

```json
{
  "textOptions": {
    "trim": true,
    "normalizeWhitespace": false,
    "lowercase": false,
    "uppercase": false,
    "pattern": "regex",
    "join": ", "
  }
}
```

### Number Options

```json
{
  "numberOptions": {
    "stripNonNumeric": true,
    "pattern": "regex",
    "thousandsSeparator": ",",
    "decimalSeparator": ".",
    "precision": 2,
    "allowNegative": true,
    "onError": "null|text|default"
  }
}
```

### Boolean Options

```json
{
  "booleanOptions": {
    "mode": "mapping|presence|attribute",
    "trueValues": ["true", "yes", "1"],
    "falseValues": ["false", "no", "0"],
    "attribute": "checked",
    "onUnknown": "false|null"
  }
}
```

### Attribute Options

```json
{
  "type": "attribute",
  "attributes": ["attr1", "attr2"],
  "attrMode": "first|firstNonEmpty|all|join",
  "attrJoin": ", "
}
```

### DateTime Options

```json
{
  "dateOptions": {
    "source": "text|attribute",
    "attribute": "datetime",
    "formats": ["ISO", "yyyy-MM-dd", "MM/dd/yyyy"],
    "timezone": "UTC",
    "output": "iso8601|epoch|epochMillis"
  }
}
```

### URL Options

```json
{
  "urlOptions": {
    "base": "https://example.com",
    "resolve": true,
    "validate": true,
    "stripQuery": false,
    "stripHash": false
  }
}
```

### List Options

```json
{
  "listOptions": {
    "itemType": "text|html|attribute|url",
    "unique": false,
    "filter": "regex",
    "limit": 10,
    "join": ", "
  }
}
```

---

## Global Defaults

Set defaults for all fields of a type:

```json
{
  "config": {
    "defaults": {
      "number": {
        "stripNonNumeric": true,
        "thousandsSeparator": ",",
        "precision": 2
      },
      "boolean": {
        "trueValues": ["yes", "available", "in stock"],
        "falseValues": ["no", "unavailable", "out of stock"]
      }
    }
  }
}
```

Field-level options override globals.

---

## Error Handling

### Ignore All Errors

```json
{
  "config": {
    "ignoreErrors": true
  }
}
```

### Per-Field Error Policy

```json
{
  "price": {
    "selector": ".price",
    "type": "number",
    "required": false,
    "default": null,
    "numberOptions": {
      "onError": "null"
    }
  }
}
```

---

## CLI Usage

```bash
# From file
node src/Main.res.mjs --schemaPath schema.json < input.html

# Inline schema
echo '<div>...</div>' | node src/Main.res.mjs --schema '{...}'

# With limit
node src/Main.res.mjs --schemaPath schema.json < input.html
```

---

## Common Selector Patterns

| Pattern               | Selects                 |
| --------------------- | ----------------------- |
| `.class`              | Elements with class     |
| `#id`                 | Element with ID         |
| `tag`                 | All elements of type    |
| `[attr]`              | Elements with attribute |
| `[attr="value"]`      | Exact attribute match   |
| `parent > child`      | Direct children         |
| `ancestor descendant` | All descendants         |
| `:first-child`        | First child element     |
| `:nth-child(n)`       | Nth child               |
| `td:nth-child(2)`     | Second `<td>` in row    |

---

## Quick Troubleshooting

| Issue                     | Solution                             |
| ------------------------- | ------------------------------------ |
| Price returns `null`      | Use `stripNonNumeric: true`          |
| Boolean always `false`    | Set custom `trueValues`              |
| Missing lazy images       | Use `attributes` array with fallback |
| Wrong row count           | Add `rowSelector`                    |
| Date not parsing          | Add format to `formats` array        |
| Relative URL not resolved | Set `base` and `resolve: true`       |
| Too many results          | Set `config.limit`                   |

---

## Example: Complete E-commerce Product

```json
{
  "name": "Product Schema",
  "config": {
    "rowSelector": ".product-card",
    "limit": 20
  },
  "fields": {
    "name": {
      "selector": "h2.product-name",
      "type": "text",
      "required": true
    },
    "price": {
      "selector": ".current-price",
      "type": "number",
      "required": true,
      "numberOptions": { "stripNonNumeric": true, "precision": 2 }
    },
    "originalPrice": {
      "selector": ".original-price",
      "type": "number",
      "default": null
    },
    "discount": {
      "selector": ".discount",
      "type": "number",
      "numberOptions": { "pattern": "([0-9]+)%" }
    },
    "inStock": {
      "selector": ".stock",
      "type": "boolean",
      "booleanOptions": {
        "trueValues": ["in stock", "available"]
      }
    },
    "rating": {
      "selector": "[itemprop='ratingValue']",
      "type": "number",
      "numberOptions": { "precision": 1 }
    },
    "reviewCount": {
      "selector": ".review",
      "type": "count"
    },
    "imageUrl": {
      "selector": "img.product-img",
      "type": "attribute",
      "attributes": ["data-src", "src"],
      "attrMode": "firstNonEmpty"
    },
    "url": {
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
      "listOptions": { "itemType": "text", "unique": true }
    }
  }
}
```
