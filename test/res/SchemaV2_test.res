open Test
open Assertions

test("URL validation false is inherited from parsed defaults", () => {
  let raw = `{"config":{"defaults":{"url":{"validate":false}}},"fields":{"u":{"selector":"a","type":"url"}}}`
  switch SchemaV2.loadSchema(~isInline=true, raw) {
  | Ok(schema) =>
    switch SchemaV2.applySchema(HtmlFixture.parse("<a href='not a url'></a>"), schema) {
    | Ok(value) => isTextEqualTo("[{\"u\":\"not a url\"}]", NodeUtil.jsonStringify(value))
    | Error(_) => failWith("Expected URL output")
    }
  | Error(_) => failWith("Expected URL schema")
  }
})

test("parsed text join defaults and field overrides reach both strategies", () => {
  ["", ",\"rowSelector\":\"div\""]->Array.forEach(row => {
    [("", "A|B"), (",\"textOptions\":{\"join\":\"\"}", "AB")]->Array.forEach(
      ((opts, expected)) => {
        let raw = `{"config":{"defaults":{"text":{"join":"|","uppercase":true}}${row}},"fields":{"t":{"selector":"span"${opts}}}}`
        switch SchemaV2.loadSchema(~isInline=true, raw) {
        | Ok(schema) =>
          switch SchemaV2.applySchema(
            HtmlFixture.parse("<div><span>a</span><span> </span><span>b</span></div>"),
            schema,
          ) {
          | Ok(value) => isTextEqualTo(`[{"t":"${expected}"}]`, NodeUtil.jsonStringify(value))
          | Error(_) => failWith("Expected inherited join output")
          }
        | Error(_) => failWith("Expected parsed join schema")
        }
      },
    )
  })
})

test("absent and null rowSelector select zip extraction", () => {
  ["{}", "{\"rowSelector\":null}"]->Array.forEach(config => {
    switch SchemaV2.loadSchema(
      ~isInline=true,
      `{"config":${config},"fields":{"i":{"selector":"i"}}}`,
    ) {
    | Ok(schema) =>
      switch SchemaV2.applySchema(HtmlFixture.parse("<i>A</i><i>B</i>"), schema) {
      | Ok(value) => isTextEqualTo("[{\"i\":\"A\"},{\"i\":\"B\"}]", NodeUtil.jsonStringify(value))
      | Error(_) => failWith("Expected zip output")
      }
    | Error(_) => failWith("Expected schema")
    }
  })
})

test("null list limit extracts all items within a row", () => {
  let raw = `{"config":{"rowSelector":"ul"},"fields":{"l":{"selector":"li","type":"list","listOptions":{"limit":null}}}}`
  switch SchemaV2.loadSchema(~isInline=true, raw) {
  | Ok(schema) =>
    switch SchemaV2.applySchema(HtmlFixture.parse("<ul><li>A</li><li>B</li></ul>"), schema) {
    | Ok(value) => isTextEqualTo("[{\"l\":[\"A\",\"B\"]}]", NodeUtil.jsonStringify(value))
    | Error(_) => failWith("Expected extraction")
    }
  | Error(_) => failWith("Expected schema")
  }
})

test("SchemaV2.loadSchema parses inline JSON", () => {
  let raw = "{\"fields\":{\"title\":{\"selector\":\".title\",\"type\":\"text\"}}}"
  isResultOk(SchemaV2.loadSchema(~isInline=true, raw))
})

test("SchemaV2.applySchema integrates parse and execute", () => {
  let raw = "{\"fields\":{\"title\":{\"selector\":\".title\",\"type\":\"text\"}},\"config\":{\"rowSelector\":\".row\"}}"
  let html = "<div class='row'><span class='title'>A</span></div><div class='row'><span class='title'>B</span></div>"
  let doc = HtmlFixture.parse(html)

  switch SchemaV2.loadSchema(~isInline=true, raw) {
  | Ok(schema) => {
      let out = SchemaV2.applySchema(doc, schema)
      isResultOk(out)
      switch out {
      | Ok(value) =>
        isTextEqualTo("[{\"title\":\"A\"},{\"title\":\"B\"}]", NodeUtil.jsonStringify(value))
      | Error(_) => ()
      }
    }
  | Error(_) => failWith("Expected loadSchema to succeed")
  }
})

test("SchemaV2.loadSchema returns InvalidJson for malformed inline schema", () => {
  switch SchemaV2.loadSchema(~isInline=true, "{\"fields\":") {
  | Error(InvalidJson(_)) => passWith("invalid json detected")
  | _ => failWith("Expected InvalidJson error")
  }
})

test("SchemaV2.loadSchema returns FileReadError for missing schema path", () => {
  switch SchemaV2.loadSchema(~isInline=false, "/tmp/definitely-missing-schema.json") {
  | Error(FileReadError(_)) => passWith("file read error detected")
  | _ => failWith("Expected FileReadError")
  }
})
