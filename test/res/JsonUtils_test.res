open Test
open Assertions

test("JsonUtils.dictGet retrieves existing string property", () => {
  let obj = {"key": "value"}
  let result: option<string> = JsonUtils.dictGet(obj, "key")
  isOptionEqualTo(Some("value"), result, ~eq=(a, b) => a == b)
})

test("JsonUtils.dictGet returns None for missing property", () => {
  let obj = {"key": "value"}
  let result: option<string> = JsonUtils.dictGet(obj, "missing")
  isOptionEqualTo(None, result, ~eq=(a, b) => a == b)
})

test("JsonUtils.dictGet retrieves integer property", () => {
  let obj = {"inner": 42}
  let inner: option<int> = JsonUtils.dictGet(obj, "inner")
  isOptionEqualTo(Some(42), inner, ~eq=(a, b) => a == b)
})
