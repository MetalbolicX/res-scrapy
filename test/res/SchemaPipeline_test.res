open Test
open Assertions

let parseSchema = raw =>
  switch SchemaV2.loadSchema(~isInline=true, raw) {
  | Ok(schema) => schema
  | Error(_) => {
      failWith("Unable to parse schema in test")
      Obj.magic()
    }
  }

let runSchema = (~html, ~schemaRaw) => {
  let doc = HtmlFixture.parse(html)
  let schema = parseSchema(schemaRaw)
  SchemaExecutor.applySchema(doc, schema)
}

let isJsonFieldEqual = (expected: string, json: JSON.t, _fieldName: string): unit => {
  let outStr = NodeUtil.jsonStringify(json)
  // Simple string contains check for field value
  isTruthy(TestHelpers.stringContains(outStr, expected))
}

test(
  "two-field pipeline: name (TextExtractor) + count (TextExtractor) produces correct merged output",
  () => {
    let html = `<html><body><span class="item">Product A</span><span class="qty">42</span></body></html>`
    let schemaRaw = `{
    "fields": {
      "name": {"selector": ".item", "type": "text"},
      "count": {"selector": ".qty", "type": "text"}
    }
  }`
    let out = runSchema(~html, ~schemaRaw)
    isResultOk(out)
    switch out {
    | Ok(value) => {
        let outStr = NodeUtil.jsonStringify(value)
        isTruthy(TestHelpers.stringContains(outStr, "\"Product A\""))
        isTruthy(TestHelpers.stringContains(outStr, "\"42\""))
      }
    | Error(_) => failWith("Expected successful extraction")
    }
  },
)

test(
  "two-field pipeline: TextExtractor + TextExtractor with different selectors produces distinct values",
  () => {
    let html = `<html><body>
    <span class="title">First Item</span>
    <span class="meta">42</span>
    <span class="title">Second Item</span>
    <span class="meta">99</span>
  </body></html>`
    let schemaRaw = `{
    "fields": {
      "title": {"selector": "span.title", "type": "text"},
      "value": {"selector": "span.meta", "type": "text"}
    }
  }`
    let out = runSchema(~html, ~schemaRaw)
    isResultOk(out)
    switch out {
    | Ok(value) => {
        let outStr = NodeUtil.jsonStringify(value)
        isTruthy(TestHelpers.stringContains(outStr, "\"First Item\""))
        isTruthy(TestHelpers.stringContains(outStr, "\"Second Item\""))
        isTruthy(TestHelpers.stringContains(outStr, "\"42\""))
        isTruthy(TestHelpers.stringContains(outStr, "\"99\""))
      }
    | Error(_) => failWith("Expected successful extraction")
    }
  },
)

test(
  "three-field pipeline with default merging: title + price (AttributeExtractor) + description (TextExtractor)",
  () => {
    let html = `<html><body>
    <h1>Shoes</h1>
    <div data-price="19.99" class="product">Great shoes</div>
  </body></html>`
    let schemaRaw = `{
    "fields": {
      "title": {"selector": "h1", "type": "text", "default": "Untitled"},
      "price": {"selector": "div.product", "type": "attribute", "attribute": "data-price"},
      "description": {"selector": "div.product", "type": "text"}
    }
  }`
    let out = runSchema(~html, ~schemaRaw)
    isResultOk(out)
    switch out {
    | Ok(value) => {
        let outStr = NodeUtil.jsonStringify(value)
        isTruthy(TestHelpers.stringContains(outStr, "\"Shoes\""))
        isTruthy(TestHelpers.stringContains(outStr, "\"19.99\""))
        isTruthy(TestHelpers.stringContains(outStr, "\"Great shoes\""))
      }
    | Error(_) => failWith("Expected successful extraction")
    }
  },
)

test(
  "three-field pipeline: all TextExtractor fields with different selectors produces distinct values",
  () => {
    let html = `<html><body>
    <article>
      <h2 class="headline">Breaking News</h2>
      <p class="summary">Something happened.</p>
      <span class="author">John Doe</span>
    </article>
  </body></html>`
    let schemaRaw = `{
    "fields": {
      "headline": {"selector": ".headline", "type": "text"},
      "summary": {"selector": ".summary", "type": "text"},
      "author": {"selector": ".author", "type": "text"}
    }
  }`
    let out = runSchema(~html, ~schemaRaw)
    isResultOk(out)
    switch out {
    | Ok(value) => {
        let outStr = NodeUtil.jsonStringify(value)
        isTruthy(TestHelpers.stringContains(outStr, "\"Breaking News\""))
        isTruthy(TestHelpers.stringContains(outStr, "\"Something happened.\""))
        isTruthy(TestHelpers.stringContains(outStr, "\"John Doe\""))
      }
    | Error(_) => failWith("Expected successful extraction")
    }
  },
)

test(
  "multi-field pipeline: missing selector on one field still produces output for found fields",
  () => {
    let html = `<html><body>
    <div class="item">Widget</div>
  </body></html>`
    let schemaRaw = `{
    "fields": {
      "name": {"selector": ".item", "type": "text"},
      "description": {"selector": ".desc", "type": "text"}
    },
    "config": {"ignoreErrors": true}
  }`
    let out = runSchema(~html, ~schemaRaw)
    isResultOk(out)
    switch out {
    | Ok(value) => {
        let outStr = NodeUtil.jsonStringify(value)
        isTruthy(TestHelpers.stringContains(outStr, "\"Widget\""))
        isTruthy(TestHelpers.stringContains(outStr, "null"))
      }
    | Error(_) => failWith("Expected successful extraction with ignoreErrors")
    }
  },
)
