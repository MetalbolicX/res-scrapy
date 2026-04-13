# Schema Examples & Use Cases

This document provides practical examples of schema configurations for common web scraping scenarios.

## Table of Contents

1. [E-commerce Product Pages](#e-commerce-product-pages)
2. [Blog/News Articles](#blognews-articles)
3. [Job Listings](#job-listings)
4. [Real Estate Listings](#real-estate-listings)
5. [Social Media Posts](#social-media-posts)
6. [Event Listings](#event-listings)
7. [Recipe Pages](#recipe-pages)
8. [Review Sites](#review-sites)
9. [Data Tables](#data-tables)
10. [Complex Nested Data](#complex-nested-data)

---

## E-commerce Product Pages

### Basic Product Information

```json
{
  "name": "Basic Product Schema",
  "config": {
    "rowSelector": ".product-item"
  },
  "fields": {
    "title": {
      "selector": "h2.product-title",
      "type": "text",
      "required": true
    },
    "price": {
      "selector": ".price-current",
      "type": "number",
      "required": true,
      "numberOptions": {
        "stripNonNumeric": true,
        "pattern": "\\$?([0-9,\\.]+)"
      }
    },
    "image": {
      "selector": "img.product-img",
      "type": "attribute",
      "attributes": ["data-lazy", "data-src", "src"],
      "attrMode": "firstNonEmpty"
    },
    "url": {
      "selector": "a.product-link",
      "type": "url",
      "urlOptions": {
        "base": "https://example.com",
        "resolve": true
      }
    }
  }
}
```

### Advanced Product with Variants

```json
{
  "name": "Product with Availability & Shipping",
  "fields": {
    "name": {
      "selector": "h1[itemprop='name']",
      "type": "text",
      "required": true
    },
    "currentPrice": {
      "selector": ".price-now",
      "type": "number",
      "numberOptions": {
        "pattern": "\\$([0-9,\\.]+)",
        "precision": 2
      }
    },
    "wasPrice": {
      "selector": ".price-was",
      "type": "number",
      "default": null
    },
    "discountPercent": {
      "selector": ".discount-badge",
      "type": "number",
      "numberOptions": {
        "pattern": "([0-9]+)%\\s*OFF"
      }
    },
    "inStock": {
      "selector": ".stock-info",
      "type": "boolean",
      "booleanOptions": {
        "mode": "mapping",
        "trueValues": ["in stock", "available", "ships today"],
        "falseValues": ["out of stock", "unavailable", "sold out"]
      }
    },
    "freeShipping": {
      "selector": ".free-shipping-badge",
      "type": "boolean",
      "booleanOptions": {
        "mode": "presence"
      }
    },
    "rating": {
      "selector": "[itemprop='ratingValue']",
      "type": "number",
      "numberOptions": {
        "precision": 1
      }
    },
    "reviewCount": {
      "selector": ".review-item",
      "type": "count"
    },
    "colors": {
      "selector": ".color-option",
      "type": "list",
      "listOptions": {
        "itemType": "attribute",
        "attribute": "data-color",
        "unique": true
      }
    },
    "images": {
      "selector": ".gallery-image",
      "type": "list",
      "listOptions": {
        "itemType": "attribute",
        "attribute": "href",
        "limit": 10
      }
    }
  }
}
```

### Product with Structured Data

```json
{
  "name": "Product with JSON-LD",
  "fields": {
    "structuredData": {
      "selector": "script[type='application/ld+json']",
      "type": "json",
      "jsonOptions": {
        "path": "$"
      }
    },
    "schemaPrice": {
      "selector": "script[type='application/ld+json']",
      "type": "json",
      "jsonOptions": {
        "path": "$.offers.price"
      }
    }
  }
}
```

---

## Blog/News Articles

### Basic Article

```json
{
  "name": "News Article Schema",
  "fields": {
    "headline": {
      "selector": "h1.article-title",
      "type": "text",
      "required": true
    },
    "author": {
      "selector": ".author-name",
      "type": "text"
    },
    "publishedDate": {
      "selector": "time.published",
      "type": "datetime",
      "dateOptions": {
        "source": "attribute",
        "attribute": "datetime",
        "output": "iso8601"
      }
    },
    "content": {
      "selector": ".article-content",
      "type": "html",
      "htmlOptions": {
        "mode": "inner",
        "stripScripts": true,
        "stripStyles": true
      }
    },
    "excerpt": {
      "selector": ".article-excerpt",
      "type": "text",
      "textOptions": {
        "trim": true,
        "normalizeWhitespace": true
      }
    },
    "tags": {
      "selector": ".tag",
      "type": "list",
      "listOptions": {
        "itemType": "text",
        "unique": true
      }
    },
    "readingTime": {
      "selector": ".reading-time",
      "type": "number",
      "numberOptions": {
        "pattern": "([0-9]+)\\s*min"
      }
    },
    "imageUrl": {
      "selector": "meta[property='og:image']",
      "type": "attribute",
      "attribute": "content"
    }
  }
}
```

### Multi-format Date Parsing

```json
{
  "name": "Flexible Date Parsing",
  "fields": {
    "publishedFlexible": {
      "selector": ".date",
      "type": "datetime",
      "dateOptions": {
        "formats": [
          "ISO",
          "MMMM dd, yyyy",
          "MM/dd/yyyy",
          "dd-MM-yyyy",
          "yyyy-MM-dd HH:mm:ss"
        ],
        "timezone": "UTC",
        "output": "iso8601"
      }
    }
  }
}
```

---

## Job Listings

```json
{
  "name": "Job Listing Schema",
  "config": {
    "rowSelector": ".job-card"
  },
  "fields": {
    "title": {
      "selector": "h2.job-title",
      "type": "text",
      "required": true
    },
    "company": {
      "selector": ".company-name",
      "type": "text",
      "required": true
    },
    "location": {
      "selector": ".job-location",
      "type": "text"
    },
    "remote": {
      "selector": ".remote-badge",
      "type": "boolean",
      "booleanOptions": {
        "mode": "presence"
      }
    },
    "salary": {
      "selector": ".salary-range",
      "type": "text",
      "textOptions": {
        "pattern": "\\$([0-9,]+)\\s*-\\s*\\$([0-9,]+)"
      }
    },
    "salaryMin": {
      "selector": ".salary-range",
      "type": "number",
      "numberOptions": {
        "pattern": "\\$([0-9,]+)",
        "stripNonNumeric": true
      }
    },
    "jobType": {
      "selector": ".job-type",
      "type": "text"
    },
    "postedDate": {
      "selector": ".posted-date",
      "type": "datetime",
      "dateOptions": {
        "formats": ["ISO", "MMMM dd, yyyy", "dd days ago"],
        "output": "iso8601"
      }
    },
    "skills": {
      "selector": ".skill-tag",
      "type": "list",
      "listOptions": {
        "itemType": "text",
        "unique": true
      }
    },
    "applyUrl": {
      "selector": "a.apply-button",
      "type": "url",
      "urlOptions": {
        "resolve": true
      }
    }
  }
}
```

---

## Real Estate Listings

```json
{
  "name": "Real Estate Listing Schema",
  "config": {
    "rowSelector": ".property-card"
  },
  "fields": {
    "address": {
      "selector": ".property-address",
      "type": "text",
      "required": true
    },
    "price": {
      "selector": ".property-price",
      "type": "number",
      "required": true,
      "numberOptions": {
        "stripNonNumeric": true,
        "precision": 0
      }
    },
    "bedrooms": {
      "selector": ".beds",
      "type": "number",
      "numberOptions": {
        "pattern": "([0-9]+)\\s*bed"
      }
    },
    "bathrooms": {
      "selector": ".baths",
      "type": "number",
      "numberOptions": {
        "pattern": "([0-9\\.]+)\\s*bath"
      }
    },
    "squareFeet": {
      "selector": ".sqft",
      "type": "number",
      "numberOptions": {
        "pattern": "([0-9,]+)\\s*sq",
        "stripNonNumeric": true
      }
    },
    "listingType": {
      "selector": ".listing-type",
      "type": "text"
    },
    "isNewListing": {
      "selector": ".new-listing-badge",
      "type": "boolean",
      "booleanOptions": {
        "mode": "presence"
      }
    },
    "hasVirtualTour": {
      "selector": ".virtual-tour-icon",
      "type": "boolean",
      "booleanOptions": {
        "mode": "presence"
      }
    },
    "images": {
      "selector": ".property-image",
      "type": "list",
      "listOptions": {
        "itemType": "attribute",
        "attribute": "src",
        "limit": 20
      }
    },
    "description": {
      "selector": ".property-description",
      "type": "text",
      "textOptions": {
        "normalizeWhitespace": true
      }
    },
    "listedDate": {
      "selector": ".listed-date",
      "type": "datetime",
      "dateOptions": {
        "formats": ["ISO", "MM/dd/yyyy"],
        "output": "iso8601"
      }
    }
  }
}
```

---

## Social Media Posts

```json
{
  "name": "Social Media Post Schema",
  "config": {
    "rowSelector": ".post"
  },
  "fields": {
    "author": {
      "selector": ".author-name",
      "type": "text",
      "required": true
    },
    "username": {
      "selector": ".username",
      "type": "text",
      "textOptions": {
        "pattern": "@([a-zA-Z0-9_]+)"
      }
    },
    "content": {
      "selector": ".post-content",
      "type": "text",
      "textOptions": {
        "normalizeWhitespace": true
      }
    },
    "timestamp": {
      "selector": "time",
      "type": "datetime",
      "dateOptions": {
        "source": "attribute",
        "attribute": "datetime",
        "output": "iso8601"
      }
    },
    "likes": {
      "selector": ".like-count",
      "type": "number",
      "numberOptions": {
        "pattern": "([0-9\\.]+)([KMB])?",
        "stripNonNumeric": false
      }
    },
    "isVerified": {
      "selector": ".verified-badge",
      "type": "boolean",
      "booleanOptions": {
        "mode": "presence"
      }
    },
    "images": {
      "selector": ".post-image",
      "type": "list",
      "listOptions": {
        "itemType": "attribute",
        "attribute": "src"
      }
    },
    "hashtags": {
      "selector": ".hashtag",
      "type": "list",
      "listOptions": {
        "itemType": "text",
        "unique": true
      }
    },
    "mentions": {
      "selector": ".mention",
      "type": "list",
      "listOptions": {
        "itemType": "text",
        "unique": true
      }
    }
  }
}
```

---

## Event Listings

```json
{
  "name": "Event Schema",
  "config": {
    "rowSelector": ".event-item"
  },
  "fields": {
    "name": {
      "selector": "h2.event-name",
      "type": "text",
      "required": true
    },
    "venue": {
      "selector": ".venue-name",
      "type": "text"
    },
    "address": {
      "selector": ".event-address",
      "type": "text"
    },
    "startDate": {
      "selector": ".start-time",
      "type": "datetime",
      "dateOptions": {
        "formats": ["ISO", "MMMM dd, yyyy 'at' hh:mm a"],
        "output": "iso8601"
      }
    },
    "endDate": {
      "selector": ".end-time",
      "type": "datetime",
      "dateOptions": {
        "formats": ["ISO", "hh:mm a"],
        "output": "iso8601"
      }
    },
    "price": {
      "selector": ".ticket-price",
      "type": "number",
      "numberOptions": {
        "pattern": "\\$([0-9\\.]+)"
      }
    },
    "isFree": {
      "selector": ".free-badge",
      "type": "boolean",
      "booleanOptions": {
        "mode": "presence"
      }
    },
    "soldOut": {
      "selector": ".sold-out-badge",
      "type": "boolean",
      "booleanOptions": {
        "mode": "presence"
      }
    },
    "categories": {
      "selector": ".category-tag",
      "type": "list",
      "listOptions": {
        "itemType": "text"
      }
    },
    "ticketUrl": {
      "selector": "a.buy-tickets",
      "type": "url",
      "urlOptions": {
        "resolve": true
      }
    }
  }
}
```

---

## Recipe Pages

```json
{
  "name": "Recipe Schema",
  "fields": {
    "title": {
      "selector": "h1.recipe-title",
      "type": "text",
      "required": true
    },
    "description": {
      "selector": ".recipe-description",
      "type": "text",
      "textOptions": {
        "normalizeWhitespace": true
      }
    },
    "prepTime": {
      "selector": ".prep-time",
      "type": "number",
      "numberOptions": {
        "pattern": "([0-9]+)\\s*min"
      }
    },
    "cookTime": {
      "selector": ".cook-time",
      "type": "number",
      "numberOptions": {
        "pattern": "([0-9]+)\\s*min"
      }
    },
    "servings": {
      "selector": ".servings",
      "type": "number",
      "numberOptions": {
        "pattern": "([0-9]+)\\s*serving"
      }
    },
    "calories": {
      "selector": ".calories",
      "type": "number",
      "numberOptions": {
        "pattern": "([0-9]+)\\s*cal"
      }
    },
    "rating": {
      "selector": "[itemprop='ratingValue']",
      "type": "number",
      "numberOptions": {
        "precision": 1
      }
    },
    "ingredients": {
      "selector": ".ingredient",
      "type": "list",
      "listOptions": {
        "itemType": "text"
      }
    },
    "instructions": {
      "selector": ".instruction-step",
      "type": "list",
      "listOptions": {
        "itemType": "text"
      }
    },
    "isVegetarian": {
      "selector": ".vegetarian-badge",
      "type": "boolean",
      "booleanOptions": {
        "mode": "presence"
      }
    },
    "isGlutenFree": {
      "selector": ".gluten-free-badge",
      "type": "boolean",
      "booleanOptions": {
        "mode": "presence"
      }
    },
    "images": {
      "selector": ".recipe-image",
      "type": "list",
      "listOptions": {
        "itemType": "attribute",
        "attribute": "src"
      }
    }
  }
}
```

---

## Review Sites

```json
{
  "name": "Product Review Schema",
  "config": {
    "rowSelector": ".review-card"
  },
  "fields": {
    "reviewerName": {
      "selector": ".reviewer-name",
      "type": "text"
    },
    "rating": {
      "selector": ".star-rating",
      "type": "number",
      "numberOptions": {
        "pattern": "([0-9\\.]+)\\s*out of"
      }
    },
    "title": {
      "selector": ".review-title",
      "type": "text"
    },
    "content": {
      "selector": ".review-text",
      "type": "text",
      "textOptions": {
        "normalizeWhitespace": true
      }
    },
    "date": {
      "selector": ".review-date",
      "type": "datetime",
      "dateOptions": {
        "formats": ["ISO", "MMMM dd, yyyy"],
        "output": "iso8601"
      }
    },
    "verified": {
      "selector": ".verified-purchase",
      "type": "boolean",
      "booleanOptions": {
        "mode": "presence"
      }
    },
    "helpful": {
      "selector": ".helpful-count",
      "type": "number",
      "numberOptions": {
        "pattern": "([0-9]+)\\s*found helpful"
      }
    },
    "hasImages": {
      "selector": ".review-image",
      "type": "boolean",
      "booleanOptions": {
        "mode": "presence"
      }
    },
    "images": {
      "selector": ".review-image",
      "type": "list",
      "listOptions": {
        "itemType": "attribute",
        "attribute": "src"
      }
    }
  }
}
```

---

## Data Tables

```json
{
  "name": "Table Data Schema",
  "config": {
    "rowSelector": "table.data-table tbody tr"
  },
  "fields": {
    "rank": {
      "selector": "td:nth-child(1)",
      "type": "number"
    },
    "name": {
      "selector": "td:nth-child(2)",
      "type": "text"
    },
    "value": {
      "selector": "td:nth-child(3)",
      "type": "number",
      "numberOptions": {
        "stripNonNumeric": true
      }
    },
    "change": {
      "selector": "td:nth-child(4)",
      "type": "number",
      "numberOptions": {
        "pattern": "([+-]?[0-9\\.]+)%",
        "allowNegative": true,
        "precision": 2
      }
    },
    "status": {
      "selector": "td:nth-child(5) .status-icon",
      "type": "text",
      "textOptions": {
        "pattern": "(up|down|stable)"
      }
    }
  }
}
```

---

## Complex Nested Data

### Product with Multiple Sizes and Colors

```json
{
  "name": "Product Variants Schema",
  "fields": {
    "productName": {
      "selector": "h1.product-name",
      "type": "text",
      "required": true
    },
    "basePrice": {
      "selector": ".base-price",
      "type": "number",
      "numberOptions": {
        "stripNonNumeric": true
      }
    },
    "variants": {
      "selector": ".variant-option",
      "type": "list",
      "listOptions": {
        "itemType": "attribute",
        "attribute": "data-sku"
      }
    },
    "availableSizes": {
      "selector": ".size-option:not(.disabled)",
      "type": "list",
      "listOptions": {
        "itemType": "text"
      }
    },
    "availableColors": {
      "selector": ".color-option:not(.disabled)",
      "type": "list",
      "listOptions": {
        "itemType": "attribute",
        "attribute": "data-color-name"
      }
    }
  }
}
```

---

## Best Practices

### 1. Use `rowSelector` for repeated elements

```json
{
  "config": {
    "rowSelector": ".product-card"
  }
}
```

### 2. Provide fallback attribute order

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

### 3. Handle currency and numbers carefully

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

### 4. Use presence mode for badges

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

### 5. Parse relative dates

```json
{
  "postedDate": {
    "selector": ".posted",
    "type": "datetime",
    "dateOptions": {
      "formats": ["ISO", "MMMM dd, yyyy", "dd days ago", "yyyy-MM-dd"],
      "output": "iso8601"
    }
  }
}
```

### 6. Set global defaults

```json
{
  "config": {
    "defaults": {
      "number": {
        "stripNonNumeric": true,
        "onError": "null"
      },
      "boolean": {
        "trueValues": ["yes", "true", "available", "in stock"],
        "falseValues": ["no", "false", "unavailable", "out of stock"]
      }
    }
  }
}
```

### 7. Handle missing data gracefully

```json
{
  "optionalField": {
    "selector": ".may-not-exist",
    "type": "text",
    "required": false,
    "default": null
  }
}
```

---

## Testing Your Schema

1. **Start simple**: Test with one field at a time
2. **Validate selectors**: Use browser DevTools to verify CSS selectors
3. **Check edge cases**: Empty values, missing elements, malformed data
4. **Use `required: true`**: For critical fields that must exist
5. **Test with real data**: Use actual HTML from target sites
6. **Monitor errors**: Check extraction logs for parsing failures

Example test command:

```bash
echo '<div class="product">...</div>' | \
  node src/Main.res.mjs --schema schema.json
```
