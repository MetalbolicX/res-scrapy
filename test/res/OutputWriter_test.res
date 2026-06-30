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

test("OutputWriter - sync and async routing produce identical output for JSON", () => {
  // Both sync write and async write share routing logic, so they must
  // produce the same routing decision for the same target/format input.
  let outMock = _text => ()
  let fileReceivedSync = ref(("", ""))
  let writeFileSync = (path, text) => fileReceivedSync := (path, text)

  let jsonText = "[{\"a\":1},{\"b\":2}]"

  // Sync write with JSON format: routing emits a JSON-format file.
  let syncResult = write(~target=File("sync.json"), ~format=Json, ~jsonText, ~writeFile=writeFileSync, ~out=outMock)
  isResultOk(syncResult)
  let (_syncPath, syncText) = fileReceivedSync.contents
  isTextEqualTo("[{\"a\":1},{\"b\":2}]", syncText)

  // Routing converts JSON array → NDJSON when format is Ndjson.
  let ndjsonSyncResult = write(~target=File("sync.ndjson"), ~format=Ndjson, ~jsonText, ~writeFile=writeFileSync, ~out=outMock)
  isResultOk(ndjsonSyncResult)
  let (_syncNdjsonPath, syncNdjsonText) = fileReceivedSync.contents
  isTextEqualTo("{\"a\":1}\n{\"b\":2}", syncNdjsonText)
})

testAsync("OutputWriter - async routing produces same NDJSON conversion as sync", planned => {
  let outMock = _text => ()
  let fileReceived = ref(("", ""))
  let writeFileAsync = (path, text) => {
    fileReceived := (path, text)
    Promise.resolve()
  }
  let jsonText = "[{\"a\":1},{\"b\":2}]"

  writeAsync(~target=File("async.ndjson"), ~format=Ndjson, ~jsonText, ~writeFile=writeFileAsync, ~out=outMock)
  ->Promise.then(result => {
    isResultOk(result)
    let (path, text) = fileReceived.contents
    isTextEqualTo("async.ndjson", path)
    // Must match sync routing: JSON array of 2 objects → 2 NDJSON lines.
    isTextEqualTo("{\"a\":1}\n{\"b\":2}", text)
    planned(~planned=3, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("OutputWriter - async routing fails for non-array JSON with NDJSON format", planned => {
  let outMock = _text => ()
  let writeFileAsync = (_path, _text) => Promise.resolve()

  writeAsync(~target=File("async.ndjson"), ~format=Ndjson, ~jsonText="{\"a\":1}", ~writeFile=writeFileAsync, ~out=outMock)
  ->Promise.then(result => {
    switch result {
    | Error(AppError.WriteError(msg)) =>
      isTextEqualTo("Cannot write NDJSON output: expected extraction result to be a JSON array", msg)
    | _ => failWith("Expected WriteError for non-array NDJSON")
    }
    planned(~planned=1, ())
    Promise.resolve()
  })
  ->ignore
})
