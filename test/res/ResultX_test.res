open Test
open Assertions

test("ResultX.mapError maps error and preserves ok", () => {
  switch ResultX.mapError(Error("x"), e => e ++ "!") {
  | Error(msg) => isTextEqualTo("x!", msg)
  | Ok(_) => failWith("Expected Error")
  }

  switch ResultX.mapError(Ok(5), e => e ++ "!") {
  | Ok(v) => isIntEqualTo(5, v)
  | Error(_) => failWith("Expected Ok")
  }
})

test("ResultX.flatMap chains only Ok", () => {
  let okResult = ResultX.flatMap(Ok(2), n => Ok(n + 3))
  let errorResult = ResultX.flatMap(Error("bad"), n => Ok(n + 3))

  switch okResult {
  | Ok(v) => isIntEqualTo(5, v)
  | Error(_) => failWith("Expected Ok")
  }

  switch errorResult {
  | Error(msg) => isTextEqualTo("bad", msg)
  | Ok(_) => failWith("Expected Error")
  }
})

test("ResultX.flatten collapses nested result", () => {
  switch ResultX.flatten(Ok(Ok(7))) {
  | Ok(v) => isIntEqualTo(7, v)
  | Error(_) => failWith("Expected Ok")
  }

  switch ResultX.flatten(Ok(Error("inner"))) {
  | Error(msg) => isTextEqualTo("inner", msg)
  | Ok(_) => failWith("Expected Error")
  }
})

test("ResultX.bimap maps both branches", () => {
  switch ResultX.bimap(Ok(3), n => n * 2, e => e ++ "!") {
  | Ok(v) => isIntEqualTo(6, v)
  | Error(_) => failWith("Expected Ok")
  }

  switch ResultX.bimap(Error("oops"), n => n * 2, e => e ++ "!") {
  | Error(msg) => isTextEqualTo("oops!", msg)
  | Ok(_) => failWith("Expected Error")
  }
})
