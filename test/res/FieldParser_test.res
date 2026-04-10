open Test
open Assertions
open FieldTypes

let isMissingSelector = e =>
  switch e {
  | MissingFields(_) => true
  | _ => false
  }

let isInvalidType = e =>
  switch e {
  | InvalidFieldType(_) => true
  | _ => false
  }

test("FieldParser.parseField defaults type to text", () => {
  let raw = TestHelpers.objectFromJsonString("{\"selector\":\".title\"}")
  switch FieldParser.parseField(raw, "title") {
  | Ok(field) =>
    switch field.fieldType {
    | Text(_) => passWith("default text type")
    | _ => failWith("Expected default field type Text")
    }
  | Error(_) => failWith("Expected parseField success")
  }
})

test("FieldParser.parseField returns MissingFields when selector is absent", () => {
  let raw = TestHelpers.objectFromJsonString("{\"type\":\"text\"}")
  switch FieldParser.parseField(raw, "title") {
  | Error(e) => isTruthy(isMissingSelector(e))
  | Ok(_) => failWith("Expected selector missing error")
  }
})

test("FieldParser.parseField returns InvalidFieldType for unknown type", () => {
  let raw = TestHelpers.objectFromJsonString("{\"selector\":\".x\",\"type\":\"x-unknown\"}")
  switch FieldParser.parseField(raw, "title") {
  | Error(e) => isTruthy(isInvalidType(e))
  | Ok(_) => failWith("Expected invalid type error")
  }
})

test("FieldParser.parseField parses required and default", () => {
  let raw = TestHelpers.objectFromJsonString(
    "{\"selector\":\".price\",\"type\":\"number\",\"required\":true,\"default\":0}",
  )
  switch FieldParser.parseField(raw, "price") {
  | Ok(field) => {
      isTruthy(field.required)
      isTruthy(field.default == Some(TestHelpers.jsonFromString("0")))
    }
  | Error(_) => failWith("Expected parseField success")
  }
})
