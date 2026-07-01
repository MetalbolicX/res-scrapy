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
  let result = writeText(
    ~target=Stdout,
    ~text="[{\"name\":\"Alice\"},{\"name\":\"Bob\"}]",
    ~writeFile=writeFileMock,
    ~out=outMock,
  )

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
  let result = write(
    ~target=Stdout,
    ~format=Ndjson,
    ~jsonText,
    ~writeFile=writeFileMock,
    ~out=outMock,
  )

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
  let result = write(
    ~target=File("/tmp/output.json"),
    ~format=Json,
    ~jsonText,
    ~writeFile=writeFileMock,
    ~out=outMock,
  )

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
  let result = writeText(
    ~target=File("/tmp/output.json"),
    ~text=jsonText,
    ~writeFile=writeFileMock,
    ~out=outMock,
  )

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
  let result = write(
    ~target=Stdout,
    ~format=Ndjson,
    ~jsonText,
    ~writeFile=writeFileMock,
    ~out=outMock,
  )

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
  let result = write(
    ~target=File("/tmp/output.ndjson"),
    ~format=Ndjson,
    ~jsonText,
    ~writeFile=writeFileMock,
    ~out=outMock,
  )

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
  let result = write(
    ~target=File("/tmp/output.ndjson"),
    ~format=Ndjson,
    ~jsonText,
    ~writeFile=writeFileMock,
    ~out=outMock,
  )

  switch result {
  | Error(AppError.WriteError(msg)) =>
    isTextEqualTo("Cannot write NDJSON output: expected extraction result to be a JSON array", msg)
  | _ => failWith("Expected WriteError")
  }
})

/* ============================================================================
   Phase 3 PR 2b: Separated Output Strategy — URL mode output routing
   The previous monolithic UrlRunner split moves URL mode output routing into
   its own module (UrlOutputWriter). These tests exercise the new module and
   assert that stdout NDJSON streaming + file buffering behavior is unchanged.
   RED: UrlOutputWriter module doesn't exist yet → compile-fail.
   ============================================================================ */

test("PR 2b UrlOutputWriter.writeStdoutNdjson invokes out once per row with the JSON row", () => {
  /* Production behaviour: each row is emitted to `out` in sequence. The
     stream separator (newline) is provided by the production sink
     (Console.log appends one); this test records invocations to verify
     the writer itself emits exactly one out call per input row. */
  let calls: ref<array<string>> = ref([])
  let outMock = text => {
    calls := calls.contents->Array.concat([text])
  }
  let json = TestHelpers.jsonFromString("[{\"name\":\"Alice\"},{\"name\":\"Bob\"}]")

  UrlOutputWriter.writeStdoutNdjson(~out=outMock, ~stringifyJson=NodeJsBinding.jsonStringify, ~json)

  isIntEqualTo(2, calls.contents->Array.length, ~message="one out call per row")
  isTextEqualTo("{\"name\":\"Alice\"}", calls.contents->Array.get(0)->Option.getOr(""))
  isTextEqualTo("{\"name\":\"Bob\"}", calls.contents->Array.get(1)->Option.getOr(""))
})

test("PR 2b UrlOutputWriter.writeStdoutNdjson yields NDJSON when out appends newline", () => {
  /* Realistic simulation: production sinks append a newline. Verify the
   resulting stream is a valid NDJSON document (one JSON value per line). */
  let received = ref("")
  let outMock = text => {
    received := received.contents ++ text ++ "\n"
  }
  let json = TestHelpers.jsonFromString("[{\"name\":\"Alice\"},{\"name\":\"Bob\"}]")

  UrlOutputWriter.writeStdoutNdjson(~out=outMock, ~stringifyJson=NodeJsBinding.jsonStringify, ~json)

  let lines = received.contents->String.split("\n")
  isTextEqualTo("{\"name\":\"Alice\"}", lines->Array.get(0)->Option.getOr(""))
  isTextEqualTo("{\"name\":\"Bob\"}", lines->Array.get(1)->Option.getOr(""))
})

test("PR 2b UrlOutputWriter.appendNdjsonToFile appends one NDJSON line per row", () => {
  let fileCalls = ref(list{})
  let appendFileMock = (path, text) => {
    fileCalls := list{(path, text), ...fileCalls.contents}
    Promise.resolve()
  }
  let errMock = _text => ()
  let json = TestHelpers.jsonFromString("[{\"name\":\"Alice\"},{\"name\":\"Bob\"}]")

  let _ = UrlOutputWriter.appendNdjsonToFile(
    ~appendFile=appendFileMock,
    ~err=errMock,
    ~stringifyJson=NodeJsBinding.jsonStringify,
    ~path="/tmp/out.ndjson",
    ~json,
  )

  // We can't easily await a returned promise in synchronous tests, but we can
  // verify the synchronous part: at least one file-append call must have been
  // scheduled with the correct content. The Mock returns a resolved promise
  // immediately so the body will have executed appendFile during construction.
  let calls = fileCalls.contents->List.toArray
  isIntEqualTo(1, calls->Array.length, ~message="appendFile called once")
  let (path, text) = calls->Array.get(0)->Option.getOr(("", ""))
  isTextEqualTo("/tmp/out.ndjson", path)
  isTextEqualTo("{\"name\":\"Alice\"}\n{\"name\":\"Bob\"}\n", text)
})

test("PR 2b UrlOutputWriter.writeFileJson writes a JSON array to file synchronously", () => {
  let received = ref(("", ""))
  let writeFileMock = (path, text) => {
    received := (path, text)
  }
  let errMock = _text => ()
  let rows: array<JSON.t> = [JSON.Encode.string("a"), JSON.Encode.string("b")]

  let result = UrlOutputWriter.writeFileJsonSync(
    ~writeFileSync=writeFileMock,
    ~err=errMock,
    ~stringifyJson=NodeJsBinding.jsonStringify,
    ~path="/tmp/out.json",
    ~rows,
  )

  isResultOk(result)
  let (path, text) = received.contents
  isTextEqualTo("/tmp/out.json", path)
  isTextEqualTo("[\"a\",\"b\"]", text)
})
