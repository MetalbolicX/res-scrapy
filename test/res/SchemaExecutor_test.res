open Test
open Assertions

let parseSchema = raw =>
  switch SchemaV2.loadSchema(~isInline=true, raw) {
  | Ok(schema) => schema
  | Error(_) => {
      failWith("Unable to parse schema in test")
      Obj.magic(())
    }
  }

test("SchemaExecutor routes to RowExtractor when rowSelector is set", () => {
  let html =
    "<ul><li class='row'><span class='title'>A</span></li><li class='row'><span class='title'>B</span></li></ul>"
  let schemaRaw =
    "{\"fields\":{\"title\":{\"selector\":\".title\",\"type\":\"text\"}},\"config\":{\"rowSelector\":\".row\"}}"
  let doc = HtmlFixture.parse(html)
  let schema = parseSchema(schemaRaw)
  let out = SchemaExecutor.applySchema(doc, schema)
  isResultOk(out)
  switch out {
  | Ok(value) =>
    isTextEqualTo("[{\"title\":\"A\"},{\"title\":\"B\"}]", NodeJsBinding.jsonStringify(value))
  | Error(_) => ()
  }
})

test("SchemaExecutor routes to ZipExtractor when rowSelector is absent", () => {
  let html = "<h2>A</h2><h2>B</h2><span>1</span><span>2</span>"
  let schemaRaw =
    "{\"fields\":{\"title\":{\"selector\":\"h2\",\"type\":\"text\"},\"rank\":{\"selector\":\"span\",\"type\":\"number\"}}}"
  let doc = HtmlFixture.parse(html)
  let schema = parseSchema(schemaRaw)
  let out = SchemaExecutor.applySchema(doc, schema)
  isResultOk(out)
  switch out {
  | Ok(value) =>
    isTextEqualTo("[{\"title\":\"A\",\"rank\":1},{\"title\":\"B\",\"rank\":2}]", NodeJsBinding.jsonStringify(value))
  | Error(_) => ()
  }
})
