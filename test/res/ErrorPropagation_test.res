open Test
open Assertions
open TestHelpers

let parseSchema = raw =>
  switch SchemaV2.loadSchema(~isInline=true, raw) {
  | Ok(schema) => schema
  | Error(_) => {
      failWith("Unable to parse schema in test")
      Obj.magic(())
    }
  }

let runSchema = (~html, ~schemaRaw) => {
  let doc = HtmlFixture.parse(html)
  let schema = parseSchema(schemaRaw)
  SchemaExecutor.applySchema(doc, schema)
}

test("missing required field triggers error with correct field name and selector", () => {
  let html = `<html><body><div class="row">Product</div></body></html>`
  let schemaRaw = `{
    "fields": {
      "name": {"selector": ".row", "type": "text"},
      "price": {"selector": ".price", "type": "number", "required": true}
    },
    "config": {"rowSelector": ".row"}
  }`
  let out = runSchema(~html, ~schemaRaw)
  switch out {
  | Error(RequiredFieldMissing({fieldName, selector})) => {
      isTextEqualTo("price", fieldName)
      isTextEqualTo(".price", selector)
    }
  | Ok(_) => failWith("Expected RequiredFieldMissing error for missing required field")
  | Error(_) => failWith("Expected RequiredFieldMissing error but got other error")
  }
})

test("missing required field in zip mode triggers error with correct field name", () => {
  let html = `<html><body><h1>Title</h1></body></html>`
  let schemaRaw = `{
    "fields": {
      "title": {"selector": "h1", "type": "text"},
      "missingField": {"selector": ".nonexistent", "type": "text", "required": true}
    }
  }`
  let out = runSchema(~html, ~schemaRaw)
  switch out {
  | Error(RequiredFieldMissing({fieldName, selector})) => {
      isTextEqualTo("missingField", fieldName)
      isTextEqualTo(".nonexistent", selector)
    }
  | Ok(_) => failWith("Expected RequiredFieldMissing error")
  | Error(_) => failWith("Expected RequiredFieldMissing error")
  }
})

test("schema without type defaults to text extractor", () => {
  let html = `<html><body><div class="item">Product</div></body></html>`
  let raw = `{"fields": {"field1": {"selector": ".item"}}}`
  let out = runSchema(~html, ~schemaRaw=raw)
  isResultOk(out)
  switch out {
  | Ok(value) => {
      let outStr = NodeJsBinding.jsonStringify(value)
      isTruthy(TestHelpers.stringContains(outStr, "\"Product\""))
    }
  | Error(_) => failWith("Expected successful extraction with default text type")
  }
})

test("invalid schema JSON returns InvalidJson error", () => {
  let raw = `{"fields": {"field1": {"selector": ".item", "type":`
  let out = SchemaV2.loadSchema(~isInline=true, raw)
  switch out {
  | Error(InvalidJson(_)) => passWith("invalid json detected")
  | Ok(_) => failWith("Expected InvalidJson error for malformed JSON")
  | Error(_) => failWith("Expected InvalidJson error")
  }
})

test("missing selector in optional field produces null, not error", () => {
  let html = `<html><body><div class="item">Product</div></body></html>`
  let schemaRaw = `{
    "fields": {
      "name": {"selector": ".item", "type": "text"},
      "comments": {"selector": ".comments", "type": "text"}
    }
  }`
  let out = runSchema(~html, ~schemaRaw)
  isResultOk(out)
  switch out {
  | Ok(value) => {
      let outStr = NodeJsBinding.jsonStringify(value)
      isTruthy(TestHelpers.stringContains(outStr, "\"Product\""))
      isTruthy(TestHelpers.stringContains(outStr, "null"))
    }
  | Error(_) => failWith("Expected successful extraction with null for missing optional field")
  }
})

test("optional field with default value uses default when selector missing", () => {
  let html = `<html><body><div class="item">Product</div></body></html>`
  let schemaRaw = `{
    "fields": {
      "name": {"selector": ".item", "type": "text"},
      "notes": {"selector": ".notes", "type": "text", "default": "No notes available"}
    },
    "config": {"ignoreErrors": true}
  }`
  let out = runSchema(~html, ~schemaRaw)
  isResultOk(out)
  switch out {
  | Ok(value) => {
      let outStr = NodeJsBinding.jsonStringify(value)
      isTruthy(TestHelpers.stringContains(outStr, "No notes available"))
    }
  | Error(_) => failWith("Expected successful extraction with default value")
  }
})

test("multiple required fields with one missing triggers single error (first found)", () => {
  let html = `<html><body><div class="item">Product</div></body></html>`
  let schemaRaw = `{
    "fields": {
      "name": {"selector": ".item", "type": "text"},
      "price": {"selector": ".price", "type": "number", "required": true},
      "sku": {"selector": ".sku", "type": "text", "required": true}
    },
    "config": {"rowSelector": ".item"}
  }`
  let out = runSchema(~html, ~schemaRaw)
  switch out {
  | Error(RequiredFieldMissing({fieldName, selector})) => {
      isTextEqualTo("price", fieldName)
      isTextEqualTo(".price", selector)
    }
  | Ok(_) => failWith("Expected RequiredFieldMissing error")
  | Error(_) => failWith("Expected RequiredFieldMissing error for first missing required field")
  }
})

test("ignoreErrors mode with required missing field returns default for that field", () => {
  let html = `<html><body><div class="item">Product</div></body></html>`
  let schemaRaw = `{
    "fields": {
      "name": {"selector": ".item", "type": "text"},
      "price": {"selector": ".price", "type": "number", "required": true, "default": 0}
    },
    "config": {"ignoreErrors": true}
  }`
  let out = runSchema(~html, ~schemaRaw)
  isResultOk(out)
  switch out {
  | Ok(value) => {
      let outStr = NodeJsBinding.jsonStringify(value)
      isTruthy(TestHelpers.stringContains(outStr, "\"Product\""))
      isTruthy(TestHelpers.stringContains(outStr, "0"))
    }
  | Error(_) => failWith("Expected successful extraction with ignoreErrors")
  }
})

test("extraction error propagates through pipeline with original message", () => {
  let schemaRaw = `{
      "fields": {
        "field1": {"selector": ".item", "type": "text"},
      "field2": {"selector": ".item", "type": "nonexistent_type"}
    }
  }`
  let out = SchemaV2.loadSchema(~isInline=true, schemaRaw)
  switch out {
  | Error(InvalidFieldType({field, _})) => {
      isTextEqualTo("field2", field)
    }
  | Ok(_) => failWith("Expected error for invalid field type")
  | Error(_) => failWith("Expected InvalidFieldType error")
  }
})

test("file read error for missing schema file propagates correctly", () => {
  let out = SchemaV2.loadSchema(~isInline=false, "/tmp/definitely-missing-schema-file-12345.json")
  switch out {
  | Error(FileReadError(msg)) => isTruthy(TestHelpers.stringContains(msg, "definitely-missing"))
  | Ok(_) => failWith("Expected FileReadError for missing schema file")
  | Error(_) => failWith("Expected FileReadError")
  }
})

test("UrlRunner parseFailureReason preserves AppError message", () => {
  let err: AppError.appError = AppError.InputError("custom parse failure: bad HTML")
  let reason = UrlRunner.formatParseFailureReason(err)
  isTextEqualTo("custom parse failure: bad HTML", reason)
})

test("UrlRunner extractionFailureReason preserves underlying string", () => {
  let reason = UrlRunner.formatExtractionFailureReason("custom extract failure: schema mismatch")
  isTextEqualTo("custom extract failure: schema mismatch", reason)
})

test("UrlRunner schemaFailureReason maps schema error to human message", () => {
  let err: FieldTypes.schemaError = FieldTypes.RequiredFieldMissing({
    fieldName: "price",
    selector: ".price",
  })
  let reason = UrlRunner.formatSchemaFailureReason(err)
  stringContains(reason, "price")->isTruthy
  stringContains(reason, ".price")->isTruthy
})

test("UrlRunner schemaFailureReason preserves InvalidJson message", () => {
  let err: FieldTypes.schemaError = FieldTypes.InvalidJson("bad json at line 5")
  let reason = UrlRunner.formatSchemaFailureReason(err)
  stringContains(reason, "bad json at line 5")->isTruthy
})
