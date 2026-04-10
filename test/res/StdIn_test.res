open Test
open Assertions
open StdIn

let isNoInput = e =>
  switch e {
  | NoInput(_) => true
  | _ => false
  }

let isEmptyContent = e =>
  switch e {
  | EmptyContent(_) => true
  | _ => false
  }

let isReadError = e =>
  switch e {
  | ReadError(_) => true
  | _ => false
  }

test("hasStdinData reflects actual stdin TTY state", () => {
  let isTTY: option<bool> = %raw("process.stdin.isTTY")
  let expected = switch isTTY {
  | Some(true) => false
  | _ => true
  }
  isTruthy(hasStdinData() == expected)
})

test("NoInput error message is descriptive", () => {
  let msg = "No HTML input provided via stdin"
  switch NoInput(msg) {
  | NoInput(m) => isTextEqualTo(msg, m)
  | _ => failWith("Expected NoInput variant")
  }
})

test("EmptyContent error message is descriptive", () => {
  let msg = "Empty HTML content received from stdin"
  switch EmptyContent(msg) {
  | EmptyContent(m) => isTextEqualTo(msg, m)
  | _ => failWith("Expected EmptyContent variant")
  }
})

test("ReadError error message includes context", () => {
  let msg = "Error reading stdin: something went wrong"
  switch ReadError(msg) {
  | ReadError(m) => isTextEqualTo(msg, m)
  | _ => failWith("Expected ReadError variant")
  }
})

test("stdInError variants can be discriminated cleanly", () => {
  let errors: array<stdInError> = [
    NoInput("no input"),
    EmptyContent("empty"),
    ReadError("read failed"),
  ]
  isIntEqualTo(3, Array.length(errors))
  isTruthy(errors->Array.map(isNoInput) == [true, false, false])
  isTruthy(errors->Array.map(isEmptyContent) == [false, true, false])
  isTruthy(errors->Array.map(isReadError) == [false, false, true])
})
