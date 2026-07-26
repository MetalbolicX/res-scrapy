open Test
open Assertions
open UrlOutputWriter

let _ = testAsync("UrlOutputWriter - appendNdjsonToFile returns Ok(()) on success", planned => {
  let fileReceived = ref(("", ""))
  let errReceived = ref("")
  let appendFileMock = (path, text) => {
    fileReceived := (path, text)
    Promise.resolve()
  }
  let errMock = msg => errReceived := msg
  let stringifyJson = NodeUtil.jsonStringify
  let aValue = JSON.Encode.int(1)
  let row = JSON.Encode.object(Dict.fromArray([("a", aValue)]))
  let json = JSON.Encode.array([row])

  appendNdjsonToFile(
    ~appendFile=appendFileMock,
    ~err=errMock,
    ~stringifyJson,
    ~path="out.ndjson",
    ~json,
  )
  ->Promise.then(result => {
    isResultOk(result)
    isTextEqualTo("", errReceived.contents)
    let (path, text) = fileReceived.contents
    isTextEqualTo("out.ndjson", path)
    isTextEqualTo("{\"a\":1}\n", text)
    planned(~planned=4, ())
    Promise.resolve()
  })
  ->ignore
})

let _ = testAsync(
  "UrlOutputWriter - appendNdjsonToFile returns Error and warns on appendFile failure",
  planned => {
    let appendFileMock = (_path, _text) => {
      %raw(`Promise.reject(new Error("Disk full"))`)
    }
    let errReceived = ref("")
    let errMock = msg => errReceived := msg
    let stringifyJson = NodeUtil.jsonStringify
    let aValue = JSON.Encode.int(1)
    let row = JSON.Encode.object(Dict.fromArray([("a", aValue)]))
    let json = JSON.Encode.array([row])

    appendNdjsonToFile(
      ~appendFile=appendFileMock,
      ~err=errMock,
      ~stringifyJson,
      ~path="out.ndjson",
      ~json,
    )
    ->Promise.then(result => {
      switch result {
      | Error(AppError.WriteError(msg)) =>
        isTextEqualTo(`Failed to append to output file "out.ndjson": Disk full`, msg)
      | Error(_) => failWith("Expected WriteError on appendFile failure")
      | Ok(_) => failWith("Expected Error on appendFile failure")
      }
      isTextEqualTo(
        `Warning: Failed to append to output file "out.ndjson": Disk full`,
        errReceived.contents,
      )
      planned(~planned=2, ())
      Promise.resolve()
    })
    ->ignore
  },
)

let _ = testAsync(
  "UrlOutputWriter - appendNdjsonToFile wraps a bare JSON value as a single-row NDJSON line",
  planned => {
    let fileReceived = ref(("", ""))
    let appendFileMock = (path, text) => {
      fileReceived := (path, text)
      Promise.resolve()
    }
    let stringifyJson = NodeUtil.jsonStringify
    let bareValue = JSON.Encode.string("value")
    let json = JSON.Encode.object(Dict.fromArray([("bare", bareValue)]))

    appendNdjsonToFile(
      ~appendFile=appendFileMock,
      ~err=_ => (),
      ~stringifyJson,
      ~path="bare.ndjson",
      ~json,
    )
    ->Promise.then(result => {
      isResultOk(result)
      let (_path, text) = fileReceived.contents
      isTextEqualTo("{\"bare\":\"value\"}\n", text)
      planned(~planned=2, ())
      Promise.resolve()
    })
    ->ignore
  },
)
