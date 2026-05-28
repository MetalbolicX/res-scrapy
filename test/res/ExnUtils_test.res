open Test
open Assertions

exception MyExn(string)

@new external makeJsError: string => 'a = "Error"

test("ExnUtils.message extracts message from Error", () => {
  let jsError = makeJsError("Some error message")
  let exn = JsExn.anyToExnInternal(jsError)
  isTextEqualTo("Some error message", ExnUtils.message(exn))
})

test("ExnUtils.message returns Unknown error for non-JS exn", () => {
  isTextEqualTo("Unknown error", ExnUtils.message(MyExn("test")))
})

test("ExnUtils.message returns Unknown error when no message", () => {
  let jsError = makeJsError("")
  let exn = JsExn.anyToExnInternal(jsError)
  isTextEqualTo("", ExnUtils.message(exn))
})
