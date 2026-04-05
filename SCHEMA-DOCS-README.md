# Schema v2.0 Documentation Suite

This directory contains comprehensive documentation for the res-scrapy schema system v2.0.

## Documents Overview

### 1. [SCHEMA-SPEC.md](SCHEMA-SPEC.md) 📋

**Complete technical specification for schema v2.0**

- **Purpose:** Official reference for schema structure, field types, and options
- **Audience:** Developers implementing schema support, advanced users
- **Contents:**
  - Schema structure and validation rules
  - All 10 field types with full option specifications
  - Global configuration options
  - Extraction behavior (row selector vs. zip mode)
  - Error handling and validation
  - Default values and inheritance
  - Migration guide from v1.0
  - Complete working example

**Key Sections:**

- Field Types: Text, Attribute, HTML, Number, Boolean, DateTime, Count, URL, JSON, List
- Options: Per-type configuration (e.g., `numberOptions`, `booleanOptions`)
- Extraction Model: `rowSelector` for row-based extraction
- Defaults: Global and field-level configuration

---

### 2. [SCHEMA-EXAMPLES.md](SCHEMA-EXAMPLES.md) 💡

**Practical examples and real-world use cases**

- **Purpose:** Learn by example, copy-paste starting points
- **Audience:** End users, beginners, quick reference
- **Contents:**
  - 10+ complete schema examples for common scenarios
  - Best practices and patterns
  - Testing recommendations
  - Common pitfalls and solutions

**Example Categories:**

1. E-commerce Product Pages
2. Blog/News Articles
3. Job Listings
4. Real Estate Listings
5. Social Media Posts
6. Event Listings
7. Recipe Pages
8. Review Sites
9. Data Tables
10. Complex Nested Data

**Highlights:**

- Currency parsing: `"$29.99"` → `29.99`
- Boolean mapping: `"In Stock"` → `true`
- Multi-attribute fallback: `["data-src", "src"]`
- Date format flexibility
- Presence-based booleans for badges

---

### 3. [IMPLEMENTATION-ROADMAP.md](IMPLEMENTATION-ROADMAP.md) 🗺️

**Development plan from v1.0 (current) to v2.0 (proposed)**

- **Purpose:** Guide for implementors, prioritization, effort estimation
- **Audience:** Core contributors, maintainers
- **Contents:**
  - Current implementation analysis
  - Identified limitations and bugs
  - Phased implementation plan (5 phases)
  - Code sketches for critical changes
  - Testing strategy
  - Backwards compatibility approach
  - Effort estimates

**Implementation Phases:**

| Phase | Focus                                              | Priority | Time       |
| ----- | -------------------------------------------------- | -------- | ---------- |
| 1     | Critical fixes (number/boolean/attribute)          | **High** | 5-8 days   |
| 2     | New field types (datetime, url, count, json, list) | Medium   | 10-15 days |
| 3     | Row selector extraction model                      | **High** | 3-4 days   |
| 4     | Text/HTML options                                  | Low      | 1-2 days   |
| 5     | Global defaults                                    | Low      | 2-3 days   |

**Key Code Changes:**

- Enhanced `numberOptions` with `stripNonNumeric`, `pattern`, etc.
- Enhanced `booleanOptions` with `trueValues`, `falseValues`, `mode`
- Multi-attribute support with `firstNonEmpty` mode
- Row-based extraction with `rowSelector`

---

## Quick Start Guide

### For Users

1. **Start with examples:** Read [SCHEMA-EXAMPLES.md](SCHEMA-EXAMPLES.md) to find a similar use case
2. **Copy and adapt:** Use the closest example as a template
3. **Refer to spec:** Check [SCHEMA-SPEC.md](SCHEMA-SPEC.md) for detailed options
4. **Test incrementally:** Validate one field at a time

### For Implementors

1. **Review current state:** Read implementation roadmap's "Current State" section
2. **Understand gaps:** Review "Current Limitations" section
3. **Follow phases:** Implement Phase 1 (critical fixes) first
4. **Use code sketches:** Adapt ReScript code examples in roadmap
5. **Write tests:** Follow testing strategy in roadmap

---

## Key Features of v2.0

### 🎯 Problem Solved

**User's Original Issue:**

```bash
# This fails in v1.0:
echo '<span class="price">$29.99</span>' | \
  node src/Main.res.mjs --schema '{"fields": {"price": {"selector": ".price", "type": "number"}}}'
# Result: null ❌ (because parseFloat("$29.99") = NaN)

# And this:
echo '<div class="in-stock">In Stock</div>' | \
  node src/Main.res.mjs --schema '{"fields": {"inStock": {"selector": ".in-stock", "type": "boolean"}}}'
# Result: false ❌ (because "In Stock" !== "true")
```

**v2.0 Solution:**

```json
{
  "fields": {
    "price": {
      "selector": ".price",
      "type": "number",
      "numberOptions": {
        "stripNonNumeric": true
      }
    },
    "inStock": {
      "selector": ".in-stock",
      "type": "boolean",
      "booleanOptions": {
        "trueValues": ["in stock", "available"]
      }
    }
  }
}
```

### 🚀 Major Enhancements

1. **Smart Number Parsing**
   - Strip currency symbols, commas, percentage signs
   - Regex pattern extraction
   - Locale-aware parsing
   - Fallback policies

2. **Flexible Boolean Logic**
   - Custom true/false value lists
   - Presence mode (element exists → true)
   - Attribute mode (checked attribute)
   - Pattern matching

3. **Multi-Attribute Fallback**
   - Try multiple attributes in order
   - Common for lazy-loaded images: `["data-lazy-src", "data-src", "src"]`
   - Modes: first, firstNonEmpty, all, join

4. **Row-Based Extraction**
   - Define `rowSelector` to anchor fields to row containers
   - More intuitive than zip-by-first-field
   - Example: `"rowSelector": ".product-card"`

5. **New Field Types**
   - `datetime` - parse dates with multiple formats
   - `url` - resolve and validate URLs
   - `count` - count matching elements
   - `json` - extract embedded JSON (e.g., JSON-LD)
   - `list` - collect multiple matches into array

6. **Global Defaults**
   - Set defaults for all fields of a type
   - Field-level options override globals
   - Reduce repetition in large schemas

---

## Comparison: v1.0 vs v2.0

### Field Type Support

| Type        | v1.0           | v2.0        | Options                                 |
| ----------- | -------------- | ----------- | --------------------------------------- |
| `text`      | ✅ Basic       | ✅ Enhanced | trim, normalize, pattern, join          |
| `attribute` | ✅ Single      | ✅ Multiple | fallback order, modes                   |
| `html`      | ✅ innerHTML   | ✅ Both     | inner/outer, strip scripts/styles       |
| `number`    | ⚠️ Basic       | ✅ Robust   | strip chars, pattern, locale, precision |
| `boolean`   | ⚠️ "true" only | ✅ Flexible | mapping, presence, attribute modes      |
| `datetime`  | ❌             | ✅ New      | multiple formats, timezone, output      |
| `url`       | ❌             | ✅ New      | resolve, validate, strip query/hash     |
| `count`     | ❌             | ✅ New      | min/max validation                      |
| `json`      | ❌             | ✅ New      | JSONPath, validation                    |
| `list`      | ❌             | ✅ New      | typed items, unique, filter             |

### Extraction Model

| Feature                      | v1.0 | v2.0             |
| ---------------------------- | ---- | ---------------- |
| Zip-by-first-field           | ✅   | ✅ (fallback)    |
| Row-based with `rowSelector` | ❌   | ✅ (recommended) |
| Relative selectors           | ❌   | ✅               |
| Field-level `multiple`       | ❌   | ✅               |

### Configuration

| Feature               | v1.0 | v2.0 |
| --------------------- | ---- | ---- |
| Global `ignoreErrors` | ✅   | ✅   |
| Global `limit`        | ✅   | ✅   |
| Global `rowSelector`  | ❌   | ✅   |
| Global field defaults | ❌   | ✅   |
| Per-field options     | ❌   | ✅   |

---

## Example Migration

### v1.0 Schema (limited)

```json
{
  "fields": {
    "price": {
      "selector": ".price",
      "type": "text",
      "required": true
    },
    "image": {
      "selector": "img",
      "type": "attribute",
      "attribute": "src"
    }
  }
}
```

**Issues:**

- Price is text, requires manual parsing
- No fallback if `src` is empty (lazy loading)
- No type coercion

### v2.0 Schema (enhanced)

```json
{
  "config": {
    "rowSelector": ".product-card"
  },
  "fields": {
    "price": {
      "selector": ".price",
      "type": "number",
      "required": true,
      "numberOptions": {
        "stripNonNumeric": true,
        "precision": 2
      }
    },
    "image": {
      "selector": "img",
      "type": "attribute",
      "attributes": ["data-lazy-src", "data-src", "src"],
      "attrMode": "firstNonEmpty"
    }
  }
}
```

**Improvements:**

- Typed number with automatic parsing
- Multi-attribute fallback
- Row-based extraction (more reliable)

---

## Common Patterns

### Currency Extraction

```json
{
  "type": "number",
  "numberOptions": {
    "stripNonNumeric": true,
    "pattern": "\\$?([0-9,\\.]+)"
  }
}
```

### Human-Readable Boolean

```json
{
  "type": "boolean",
  "booleanOptions": {
    "trueValues": ["available", "in stock", "yes"],
    "falseValues": ["sold out", "unavailable", "no"]
  }
}
```

### Badge Presence Check

```json
{
  "type": "boolean",
  "booleanOptions": {
    "mode": "presence"
  }
}
```

### Lazy-Loaded Images

```json
{
  "type": "attribute",
  "attributes": ["data-lazy-src", "data-src", "src"],
  "attrMode": "firstNonEmpty"
}
```

### Flexible Date Parsing

```json
{
  "type": "datetime",
  "dateOptions": {
    "formats": ["ISO", "MMMM dd, yyyy", "MM/dd/yyyy"],
    "output": "iso8601"
  }
}
```

### Collect Tags

```json
{
  "type": "list",
  "listOptions": {
    "itemType": "text",
    "unique": true
  }
}
```

---

## Testing Your Schema

### Command-Line Testing

```bash
# Test from file
echo '<div>...</div>' | node src/Main.res.mjs --schemaPath schema.json

# Test inline
echo '<div>...</div>' | node src/Main.res.mjs --schema '{"fields": {...}}'

# Test with sample files
node src/Main.res.mjs --schemaPath schema.json < sample.html
```

### Validation Checklist

- ✅ All required fields extract successfully
- ✅ Number fields parse currency/formatted numbers
- ✅ Boolean fields recognize custom values
- ✅ Attribute fallbacks work for lazy-loaded content
- ✅ Row selector produces expected row count
- ✅ Errors are handled gracefully (or ignored if configured)
- ✅ Default values apply when elements missing

---

## API Reference Summary

### Schema Top-Level

```typescript
{
  name?: string;
  description?: string;
  version?: string;
  rowSelector?: string;
  fields: Fields;
  config?: Config;
}
```

### Field Definition

```typescript
{
  selector: string;
  type: FieldType;
  required?: boolean;
  default?: any;
  multiple?: boolean;
  [typeOptions]?: TypeOptions;
}
```

### Config

```typescript
{
  ignoreErrors?: boolean;
  limit?: number;
  rowSelector?: string;
  defaults?: {
    text?: TextOptions;
    number?: NumberOptions;
    boolean?: BooleanOptions;
    datetime?: DateOptions;
    url?: URLOptions;
  };
}
```

---

## Contributing

### To Add Examples

1. Edit [SCHEMA-EXAMPLES.md](SCHEMA-EXAMPLES.md)
2. Add a new category or enhance existing
3. Include working schema JSON
4. Show expected input/output

### To Propose Features

1. Check [SCHEMA-SPEC.md](SCHEMA-SPEC.md) to avoid duplicates
2. Open issue describing use case
3. Reference similar implementations if known
4. Consider backwards compatibility

### To Implement Features

1. Follow [IMPLEMENTATION-ROADMAP.md](IMPLEMENTATION-ROADMAP.md) phases
2. Start with Phase 1 (critical fixes)
3. Write tests for each feature
4. Update all three docs with changes

---

## FAQ

**Q: Why not just return everything as text?**
A: Type coercion at extraction time reduces downstream processing and catches errors early. Users who prefer text can use `"type": "text"`.

**Q: What if I need a field type not listed?**
A: Use `"type": "text"` with `"textOptions": {"pattern": "..."}` to extract via regex, then process downstream.

**Q: How do I extract from nested structures?**
A: Use `rowSelector` to define the row container, then use relative selectors for fields within each row.

**Q: Can I extract multiple values from one element?**
A: Yes, use `"multiple": true` or `"type": "list"` with appropriate options.

**Q: How do I handle errors gracefully?**
A: Set `"config": {"ignoreErrors": true}` to skip failed fields, or use field-level `"required": false` with `"default"`.

**Q: Does this work with JavaScript websites (SPA)?**
A: No, res-scrapy works on static HTML. For dynamic content, render with a headless browser first (e.g., Puppeteer, Playwright), then pipe to res-scrapy.

---

## Additional Resources

- [Main README](README.md) - Project overview and basic usage
- [examples/](examples/) - Sample HTML and schema files
- [src/schema/Schema.res](src/schema/Schema.res) - Current implementation
- [GitHub Issues](https://github.com/MetalbolicX/res-scrapy/issues) - Bug reports and feature requests

---

## Version History

- **v2.0 (proposed):** This specification suite
- **v1.0 (current):** Basic types, zip extraction model

---

## License

Same as res-scrapy project license.
