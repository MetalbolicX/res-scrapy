open Test
open Assertions
open FieldTypes

test("ConfigParser.parseConfig uses default config when missing", () => {
  let raw = TestHelpers.objectFromJsonString("{}")
  let config = ConfigParser.parseConfig(raw)
  isTruthy(config.ignoreErrors == false)
  isIntEqualTo(0, config.limit)
  isOptionEqualTo(None, config.rowSelector, ~eq=(a, b) => a == b)
})

test("ConfigParser.parseConfig parses top-level knobs", () => {
  let raw = TestHelpers.objectFromJsonString(
    "{\"config\":{\"ignoreErrors\":true,\"limit\":5,\"rowSelector\":\".row\"}}",
  )
  let config = ConfigParser.parseConfig(raw)
  isTruthy(config.ignoreErrors)
  isIntEqualTo(5, config.limit)
  isOptionEqualTo(Some(".row"), config.rowSelector, ~eq=(a, b) => a == b)
})

test("ConfigParser.parseConfig parses defaults", () => {
  let raw = TestHelpers.objectFromJsonString(
    "{\"config\":{\"defaults\":{\"text\":{\"trim\":false},\"number\":{\"precision\":2},\"boolean\":{\"mode\":\"presence\"}}}}",
  )
  let config = ConfigParser.parseConfig(raw)
  switch config.defaults {
  | None => failWith("Expected defaults")
  | Some(d) => {
      isTruthy(d.text != None)
      isTruthy(d.number != None)
      isTruthy(d.boolean != None)
    }
  }
})
