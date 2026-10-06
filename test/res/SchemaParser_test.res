open Test
open Assertions
open FieldTypes

let isMissingFields = e =>
  switch e {
  | MissingFields(_) => true
  | _ => false
  }

test("SchemaParser.parseSchema handles object fields format", () => {
  let raw = TestHelpers.objectFromJsonString(
    "{\"name\":\"n\",\"fields\":{\"title\":{\"selector\":\".title\",\"type\":\"text\"}}}",
  )
  switch SchemaParser.parseSchema(raw) {
  | Ok(schema) => {
      isIntEqualTo(1, Array.length(schema.fields))
      isOptionEqualTo(Some("n"), schema.name, ~eq=(a, b) => a == b)
    }
  | Error(_) => failWith("Expected schema parse success")
  }
})

test("SchemaParser.parseSchema handles legacy array fields format", () => {
  let raw = TestHelpers.objectFromJsonString(
    "{\"fields\":[{\"name\":\"title\",\"selector\":\".title\",\"type\":\"text\"}]}",
  )
  switch SchemaParser.parseSchema(raw) {
  | Ok(schema) => isIntEqualTo(1, Array.length(schema.fields))
  | Error(_) => failWith("Expected legacy schema parse success")
  }
})

test("SchemaParser rejects malformed fields shapes without throwing", () => {
  let invalidSchemas = [
    "{\"fields\":42}",
    "{\"fields\":null}",
    "{\"fields\":[{\"selector\":\".x\"}]}",
    "{\"fields\":{}}",
  ]
  invalidSchemas->Array.forEach(schemaJson =>
    switch SchemaParser.parseSchema(TestHelpers.objectFromJsonString(schemaJson)) {
    | Error(_) => ()
    | Ok(_) => failWith("Expected malformed fields to be rejected")
    }
  )
})

test("SchemaV2.loadSchema returns typed errors for malformed schema", () => {
  switch SchemaV2.loadSchema(~isInline=true, "{\"fields\":42}") {
  | Error(MissingFields(_)) => ()
  | Error(_) => failWith("Expected a typed MissingFields schema error")
  | Ok(_) => failWith("Expected malformed schema to be rejected")
  }
})

test("SchemaParser.parseSchema fails when fields key is missing", () => {
  let raw = TestHelpers.objectFromJsonString("{\"name\":\"x\"}")
  switch SchemaParser.parseSchema(raw) {
  | Error(e) => isTruthy(isMissingFields(e))
  | Ok(_) => failWith("Expected MissingFields error")
  }
})
