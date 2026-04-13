# Schema Reference

Quick Summary

- Purpose: explain schema files and configuration for res-scrapy clearly and concisely.
- Most important: use `config.rowSelector` for row-based extraction; prefer schema mode for typed extraction and `--table` for HTML tables.
- Use `--schemaPath` for production schemas and `--schema` for quick tests.

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

... (archived full reference) ...
