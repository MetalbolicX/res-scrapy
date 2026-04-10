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

test("SchemaParser.parseSchema fails when fields key is missing", () => {
  let raw = TestHelpers.objectFromJsonString("{\"name\":\"x\"}")
  switch SchemaParser.parseSchema(raw) {
  | Error(e) => isTruthy(isMissingFields(e))
  | Ok(_) => failWith("Expected MissingFields error")
  }
})
