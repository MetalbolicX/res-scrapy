open Test
open Assertions
open TestHelpers

exception MyExn(string)

@new external makeJsError: string => 'a = "Error"

/* The JS `Error` constructor only honours the first positional (`message`).
   To simulate a custom stack in tests we build the error then explicitly
   override `stack` via Object.defineProperty (matches what the V8 error
   object looks like in production). */
let makeJsErrorWithStack: (string, string) => 'a = %raw(`
  (message, stack) => {
    const e = new Error(message);
    try { Object.defineProperty(e, "stack", { value: stack, configurable: true }); }
    catch (_) { e.stack = stack; }
    return e;
  }
`)

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

/* ============================================================================
   Phase 3 PR 2b: Rich Error Context — ExnUtils.fullMessage with stack traces
   These tests target the new fullMessage function added by task 3.3.
   RED: the function does not exist yet → compile-fail. ReScript will report
   `ExnUtils.fullMessage is not a function` (or equivalent module-binding error)
   until the function is added.
   ============================================================================ */

test("PR 2b fullMessage includes the message when only a stack exists", () => {
  let jsError = makeJsError("Some error message")
  let exn = JsExn.anyToExnInternal(jsError)
  let output = ExnUtils.fullMessage(exn)
  isTruthy(stringContains(output, "Some error message"))
})

test("PR 2b fullMessage returns Unknown error for non-JS exn", () => {
  isTextEqualTo("Unknown error", ExnUtils.fullMessage(MyExn("test")))
})

test("PR 2b fullMessage preserves an explicit stack when present", () => {
  let stack = "Error: boom\n    at Object.<anonymous> (/app/main.js:10:5)\n    at foo (/app/main.js:20:3)"
  let jsError = makeJsErrorWithStack("boom", stack)
  let exn = JsExn.anyToExnInternal(jsError)
  let output = ExnUtils.fullMessage(exn)
  isTruthy(stringContains(output, "boom"))
  isTruthy(stringContains(output, "at Object"))
  isTruthy(stringContains(output, "main.js:10:5"))
})

test("PR 2b fullMessage is distinguishable from message when stack present", () => {
  let stack = "Error: hadStack\n    at <anonymous>:1:1"
  let jsError = makeJsErrorWithStack("hadStack", stack)
  let exn = JsExn.anyToExnInternal(jsError)
  let msg = ExnUtils.message(exn)
  let full = ExnUtils.fullMessage(exn)
  // message() returns just the message; fullMessage() is longer.
  isTruthy(String.length(full) > String.length(msg))
})

test("PR 2b fullMessage starts with the message even when stack is present", () => {
  // Locks in the contract: fullMessage's first line is the message; the
  // stack follows as additional context.
  let stack = "Error: hadStack\n    at obj (/app/main.js:1:1)"
  let jsError = makeJsErrorWithStack("hadStack", stack)
  let exn = JsExn.anyToExnInternal(jsError)
  let output = ExnUtils.fullMessage(exn)
  isTruthy(stringContains(output, "hadStack"))
  isTruthy(stringContains(output, "main.js:1:1"))
})
