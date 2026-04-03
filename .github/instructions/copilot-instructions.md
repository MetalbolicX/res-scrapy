---
description: "Source-specific clean code conventions for clarity, safety, and maintainability."
applyTo: "src/**/*"
---

# Project overview

`res-scrapy` is a web scraper that uses `node-html-parser` and rescript to extract data from web pages. It is designed to be used cli.

## Techn Stack

- **Language**: ReScript v12.
- **HTML Parser**: `node-html-parser` v7.1.0.
- **Node.js**: v22.0.0+.

## Workflow

1. Read from the stdin the HTML content to be parsed.
2. The scraper flags will be applied to the HTML content, extracting relevant data based on predefined rules.

- The `flags` are defined in the [NodeJsBindings.res](/src/bindings/NodeJsBinding.res) file and can be customized to target specific elements, attributes, or patterns in the HTML.

3. The extracted data will be outputted to the stdout in a structured JSON format.

## Source Clean Code Practices

### 1. Operational Discipline

- Confirm requirements (scope, acceptance, constraints) before modifying logic or adding features.
- Keep each change focused: reviewable patches, one file per edit, and a clear snapshot of why work was done.
- Pair new behavior with a targeted test or validation step whenever feasible to guard the contract.
- Document assumptions or trade-offs directly in code comments or accompanying docs so future readers understand the intent.

### 2. Naming & Declarations

- Favor descriptive identifiers over abbreviations, use domain terms consistently, and limit single-letter names to conventional loop counters (`i`, `j`).
- Use `PascalCase` for classes/components, `camelCase` for variables/functions, `UPPER_SNAKE_CASE` for compile-time constants, and prefix booleans with `is`, `has`, `can`, or `should`.
- Prefer `const` for values that never reassign or inmutabilty in a given programming language. Use `let` only when mutation is required (or `mutable` in languages that support it).

### 3. Control Flow & Structure

- Handle invalid states early and return immediately to avoid deep nesting or repeated conditionals.
- Extract small, pure helper functions for reusable logic; each function should do one thing and be easy to reason about.
- Prefer readable iterators (`map`, `filter`, `reduce`, `for...of`) over manual index looping, and keep branch coverage explicit.

### 4. Async & Error Handling

- Create specific descriptive error messages that include context and potential causes to aid debugging and support.
- Log unexpected failures at the call site and propagate typed error objects so callers can make decisions (retry, fallback, bubble up). For example:

```javascript
async function fetchCatalog(signal: AbortSignal): Promise<Catalog> {
  const response = await fetch(CATALOG_URL, { signal });
  if (!response.ok) throw new Error(`Catalog request failed with ${response.status}`);
  return response.json();
}
```
