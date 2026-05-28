open Test
open Assertions
open OutputWriter

let _ = test("OutputWriter - writeText with Stdout target", () => {
  let outputReceived = ref("")
  let outMock = text => {
    outputReceived := text
  }
  let writeFileMock = (_path, _text) => {
    ()
  }

  let result = writeText(~target=Stdout, ~text="hello", ~writeFile=writeFileMock, ~out=outMock)

  isResultOk(result)
  isTextEqualTo("hello", outputReceived.contents)
})

let _ = test("OutputWriter - writeText with File target success", () => {
  let outputReceived = ref("")
  let fileReceived = ref(("", ""))
  let outMock = text => {
    outputReceived := text
  }
  let writeFileMock = (path, text) => {
    fileReceived := (path, text)
  }

  let result = writeText(~target=File("out.txt"), ~text="hello", ~writeFile=writeFileMock, ~out=outMock)

  isResultOk(result)
  isTextEqualTo("", outputReceived.contents)
  let (path, text) = fileReceived.contents
  isTextEqualTo("out.txt", path)
  isTextEqualTo("hello", text)
})

let _ = test("OutputWriter - writeText with File target failure", () => {
  let outMock = _text => ()
  @warning("-3")
  let writeFileMock = (_path, _text) => {
    Js.Exn.raiseError("Disk full")
  }

  let result = writeText(~target=File("out.txt"), ~text="hello", ~writeFile=writeFileMock, ~out=outMock)

  switch result {
  | Error(AppError.WriteError(msg)) =>
    isTextEqualTo("Failed to write output file \"out.txt\": Disk full", msg)
  | _ => failWith("Expected WriteError")
  }
})

let _ = test("OutputWriter - write Ndjson success", () => {
  let fileReceived = ref(("", ""))
  let outMock = _text => ()
  let writeFileMock = (path, text) => {
    fileReceived := (path, text)
  }

  let jsonText = "[{\"a\":1}, {\"b\":2}]"
  let result = write(~target=File("out.ndjson"), ~format=Ndjson, ~jsonText, ~writeFile=writeFileMock, ~out=outMock)

  isResultOk(result)
  let (path, text) = fileReceived.contents
  isTextEqualTo("out.ndjson", path)
  isTextEqualTo("{\"a\":1}\n{\"b\":2}", text)
})

let _ = test("OutputWriter - write Ndjson failure (not an array)", () => {
  let outMock = _text => ()
  let writeFileMock = (_path, _text) => ()

  let jsonText = "{\"a\":1}"
  let result = write(~target=File("out.ndjson"), ~format=Ndjson, ~jsonText, ~writeFile=writeFileMock, ~out=outMock)

  switch result {
  | Error(AppError.WriteError(msg)) =>
    isTextEqualTo("Cannot write NDJSON output: expected extraction result to be a JSON array", msg)
  | _ => failWith("Expected WriteError")
  }
})

let _ = test("OutputWriter - write Ndjson failure (invalid json)", () => {
  let outMock = _text => ()
  let writeFileMock = (_path, _text) => ()

  let jsonText = "invalid json"
  let result = write(~target=File("out.ndjson"), ~format=Ndjson, ~jsonText, ~writeFile=writeFileMock, ~out=outMock)

  switch result {
  | Error(AppError.WriteError(msg)) =>
    isTextEqualTo("Cannot write NDJSON output: expected extraction result to be a JSON array", msg)
  | _ => failWith("Expected WriteError")
  }
})

let _ = testAsync("OutputWriter - writeTextAsync with Stdout target", planned => {
  let outputReceived = ref("")
  let outMock = text => {
    outputReceived := text
  }
  let writeFileMock = (_path, _text) => {
    Promise.resolve(())
  }

  writeTextAsync(~target=Stdout, ~text="hello", ~writeFile=writeFileMock, ~out=outMock)
  ->Promise.then(result => {
    isResultOk(result)
    isTextEqualTo("hello", outputReceived.contents)
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->ignore
})

let _ = testAsync("OutputWriter - writeTextAsync with File target failure", planned => {
  let outMock = _text => ()
  let writeFileMock = (_path, _text) => {
    %raw(`Promise.reject(new Error("Disk full"))`)
  }

  writeTextAsync(~target=File("out.txt"), ~text="hello", ~writeFile=writeFileMock, ~out=outMock)
  ->Promise.then(result => {
    switch result {
    | Error(AppError.WriteError(msg)) =>
      isTextEqualTo("Failed to write output file \"out.txt\": Disk full", msg)
    | _ => failWith("Expected WriteError")
    }
    planned(~planned=1, ())
    Promise.resolve()
  })
  ->ignore
})
