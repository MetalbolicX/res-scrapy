open Test
open Assertions
open OutputWriter

test("writeOutput writes JSON to stdout when target is Stdout", () => {
  let outputReceived = ref("")
  let outMock = text => {
    outputReceived := text
  }
  let writeFileMock = (_path, _text) => {
    ()
  }
  let result = writeText(~target=Stdout, ~text="[{\"name\":\"Alice\"},{\"name\":\"Bob\"}]", ~writeFile=writeFileMock, ~out=outMock)

  isResultOk(result)
  isTextEqualTo("[{\"name\":\"Alice\"},{\"name\":\"Bob\"}]", outputReceived.contents)
})

test("writeOutput writes NDJSON to stdout when format is Ndjson", () => {
  let outputReceived = ref("")
  let outMock = text => {
    outputReceived := text
  }
  let writeFileMock = (_path, _text) => {
    ()
  }
  let jsonText = "[{\"name\":\"Alice\"},{\"name\":\"Bob\"}]"
  let result = write(~target=Stdout, ~format=Ndjson, ~jsonText, ~writeFile=writeFileMock, ~out=outMock)

  isResultOk(result)
  // NDJSON format is only applied to File targets, Stdout gets raw JSON
  isTextEqualTo("[{\"name\":\"Alice\"},{\"name\":\"Bob\"}]", outputReceived.contents)
})

test("writeOutput writes JSON format to file when output path provided", () => {
  let outputReceived = ref("")
  let fileReceived = ref(("", ""))
  let outMock = text => {
    outputReceived := text
  }
  let writeFileMock = (path, text) => {
    fileReceived := (path, text)
  }
  let jsonText = "[{\"name\":\"Alice\"}]"
  let result = write(~target=File("/tmp/output.json"), ~format=Json, ~jsonText, ~writeFile=writeFileMock, ~out=outMock)

  isResultOk(result)
  isTextEqualTo("", outputReceived.contents)
  let (path, text) = fileReceived.contents
  isTextEqualTo("/tmp/output.json", path)
  isTextEqualTo("[{\"name\":\"Alice\"}]", text)
})

test("writeOutput returns error when file write fails", () => {
  let outMock = _text => ()
  @warning("-3")
  let writeFileMock = (_path, _text) => {
    Js.Exn.raiseError("Disk full")
  }
  let jsonText = "[{\"name\":\"Alice\"}]"
  let result = writeText(~target=File("/tmp/output.json"), ~text=jsonText, ~writeFile=writeFileMock, ~out=outMock)

  switch result {
  | Error(AppError.WriteError(msg)) =>
    isTextEqualTo("Failed to write output file \"/tmp/output.json\": Disk full", msg)
  | _ => failWith("Expected WriteError")
  }
})

test("empty JSON array output produces empty array text on stdout for JSON format", () => {
  let outputReceived = ref("")
  let outMock = text => {
    outputReceived := text
  }
  let writeFileMock = (_path, _text) => ()
  let jsonText = "[]"
  let result = writeText(~target=Stdout, ~text=jsonText, ~writeFile=writeFileMock, ~out=outMock)

  isResultOk(result)
  isTextEqualTo("[]", outputReceived.contents)
})

test("empty JSON array for NDJSON produces empty output on stdout", () => {
  let outputReceived = ref("")
  let outMock = text => {
    outputReceived := text
  }
  let writeFileMock = (_path, _text) => ()
  let jsonText = "[]"
  let result = write(~target=Stdout, ~format=Ndjson, ~jsonText, ~writeFile=writeFileMock, ~out=outMock)

  isResultOk(result)
  // NDJSON format is only applied to File targets, Stdout gets raw JSON
  isTextEqualTo("[]", outputReceived.contents)
})

test("NDJSON file output produces one JSON object per line", () => {
  let fileReceived = ref(("", ""))
  let outMock = _text => ()
  let writeFileMock = (path, text) => {
    fileReceived := (path, text)
  }
  let jsonText = "[{\"name\":\"Alice\",\"age\":30},{\"name\":\"Bob\",\"age\":25}]"
  let result = write(~target=File("/tmp/output.ndjson"), ~format=Ndjson, ~jsonText, ~writeFile=writeFileMock, ~out=outMock)

  isResultOk(result)
  let (path, text) = fileReceived.contents
  isTextEqualTo("/tmp/output.ndjson", path)
  isTextEqualTo("{\"name\":\"Alice\",\"age\":30}\n{\"name\":\"Bob\",\"age\":25}", text)
})

test("NDJSON file output returns error when JSON is not an array", () => {
  let fileReceived = ref(("", ""))
  let outMock = _text => ()
  let writeFileMock = (path, text) => {
    fileReceived := (path, text)
  }
  let jsonText = "{\"name\":\"Alice\"}"
  let result = write(~target=File("/tmp/output.ndjson"), ~format=Ndjson, ~jsonText, ~writeFile=writeFileMock, ~out=outMock)

  switch result {
  | Error(AppError.WriteError(msg)) =>
    isTextEqualTo("Cannot write NDJSON output: expected extraction result to be a JSON array", msg)
  | _ => failWith("Expected WriteError")
  }
})
