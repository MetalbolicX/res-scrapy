open Test
open Assertions

test("guide JSON root-prefixed price extracts 42", () => {
  let raw = `{"fields":{"ld":{"selector":"script[type='application/ld+json']","type":"json","jsonOptions":{"path":"$.offers.price"}}}}`
  switch SchemaV2.loadSchema(~isInline=true, raw) {
  | Ok(schema) =>
    switch SchemaV2.applySchema(
      HtmlFixture.parse(`<script type="application/ld+json">{"offers":{"price":42}}</script>`),
      schema,
    ) {
    | Ok(value) => isTextEqualTo("[{\"ld\":42}]", NodeUtil.jsonStringify(value))
    | Error(_) => failWith("Expected guide output")
    }
  | Error(_) => failWith("Expected guide schema")
  }
})

test("schema tbody header omission respects explicit row selector", () => {
  [
    ("", "[{\"t\":[{\"A\":\"1\",\"B\":\"2\"}]}]"),
    ("\"rowSelector\":\"tr\",", "[{\"t\":[{\"A\":null,\"B\":null},{\"A\":\"1\",\"B\":\"2\"}]}]"),
  ]->Array.forEach(((selector, expected)) => {
    let raw = `{"fields":{"t":{"selector":"table","type":"table","tableOptions":{${selector}"columns":[{"name":"A","selector":"td:nth-child(1)","type":"text"},{"name":"B","selector":"td:nth-child(2)","type":"text"}]}}}}`
    switch SchemaV2.loadSchema(~isInline=true, raw) {
    | Ok(schema) =>
      switch SchemaV2.applySchema(
        HtmlFixture.parse(
          "<table><tbody><tr><th>A</th><th>B</th></tr><tr><td>1</td><td>2</td></tr></tbody></table>",
        ),
        schema,
      ) {
      | Ok(value) => isTextEqualTo(expected, NodeUtil.jsonStringify(value))
      | Error(_) => failWith("Expected schema table output")
      }
    | Error(_) => failWith("Expected schema")
    }
  })
})

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
