open Test
open Assertions

test("SchemaV2.loadSchema parses inline JSON", () => {
  let raw = "{\"fields\":{\"title\":{\"selector\":\".title\",\"type\":\"text\"}}}"
  isResultOk(SchemaV2.loadSchema(~isInline=true, raw))
})

test("SchemaV2.applySchema integrates parse and execute", () => {
  let raw =
    "{\"fields\":{\"title\":{\"selector\":\".title\",\"type\":\"text\"}},\"config\":{\"rowSelector\":\".row\"}}"
  let html = "<div class='row'><span class='title'>A</span></div><div class='row'><span class='title'>B</span></div>"
  let doc = HtmlFixture.parse(html)

  switch SchemaV2.loadSchema(~isInline=true, raw) {
  | Ok(schema) => {
      let out = SchemaV2.applySchema(doc, schema)
      isResultOk(out)
      switch out {
      | Ok(value) => isTextEqualTo("[{\"title\":\"A\"},{\"title\":\"B\"}]", NodeJsBinding.jsonStringify(value))
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
