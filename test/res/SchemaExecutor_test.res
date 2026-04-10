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

let runSchema = (~html, ~schemaRaw) => {
  let doc = HtmlFixture.parse(html)
  let schema = parseSchema(schemaRaw)
  SchemaExecutor.applySchema(doc, schema)
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

test("RowExtractor returns error for missing required fields", () => {
  let out = runSchema(
    ~html="<div class='row'><span class='title'>A</span></div>",
    ~schemaRaw="{\"fields\":{\"title\":{\"selector\":\".title\",\"type\":\"text\"},\"price\":{\"selector\":\".price\",\"type\":\"number\",\"required\":true}},\"config\":{\"rowSelector\":\".row\"}}",
  )
  switch out {
  | Error(RequiredFieldMissing({fieldName, selector})) => {
      isTextEqualTo("price", fieldName)
      isTextEqualTo(".price", selector)
    }
  | _ => failWith("Expected RequiredFieldMissing error")
  }
})

test("RowExtractor honors ignoreErrors and default for missing required", () => {
  let out = runSchema(
    ~html="<div class='row'><span class='title'>A</span></div>",
    ~schemaRaw="{\"fields\":{\"title\":{\"selector\":\".title\",\"type\":\"text\"},\"price\":{\"selector\":\".price\",\"type\":\"number\",\"required\":true,\"default\":0}},\"config\":{\"rowSelector\":\".row\",\"ignoreErrors\":true}}",
  )
  switch out {
  | Ok(value) => isTextEqualTo("[{\"title\":\"A\",\"price\":0}]", NodeJsBinding.jsonStringify(value))
  | Error(_) => failWith("Expected ignoreErrors to produce output")
  }
})

test("RowExtractor boolean presence returns false when selector is absent", () => {
  let out = runSchema(
    ~html="<div class='row'><span class='title'>A</span></div>",
    ~schemaRaw="{\"fields\":{\"available\":{\"selector\":\".flag\",\"type\":\"boolean\",\"required\":true,\"booleanOptions\":{\"mode\":\"presence\"}}},\"config\":{\"rowSelector\":\".row\"}}",
  )
  switch out {
  | Ok(value) => isTextEqualTo("[{\"available\":false}]", NodeJsBinding.jsonStringify(value))
  | Error(_) => failWith("Expected presence=false for missing selector")
  }
})

test("RowExtractor computes Count/List relative to each row", () => {
  let out = runSchema(
    ~html="<div class='row'><span class='tag'>a</span><span class='tag'>b</span></div><div class='row'><span class='tag'>c</span></div>",
    ~schemaRaw="{\"fields\":{\"tagCount\":{\"selector\":\".tag\",\"type\":\"count\"},\"tags\":{\"selector\":\".tag\",\"type\":\"list\",\"listOptions\":{\"itemType\":\"text\"}}},\"config\":{\"rowSelector\":\".row\"}}",
  )
  switch out {
  | Ok(value) =>
    isTextEqualTo(
      "[{\"tagCount\":2,\"tags\":[\"a\",\"b\"]},{\"tagCount\":1,\"tags\":[\"c\"]}]",
      NodeJsBinding.jsonStringify(value),
    )
  | Error(_) => failWith("Expected row-relative count/list output")
  }
})

test("RowExtractor limit truncates row output", () => {
  let out = runSchema(
    ~html="<div class='row'><span class='title'>A</span></div><div class='row'><span class='title'>B</span></div><div class='row'><span class='title'>C</span></div>",
    ~schemaRaw="{\"fields\":{\"title\":{\"selector\":\".title\",\"type\":\"text\"}},\"config\":{\"rowSelector\":\".row\",\"limit\":2}}",
  )
  switch out {
  | Ok(value) => isTextEqualTo("[{\"title\":\"A\"},{\"title\":\"B\"}]", NodeJsBinding.jsonStringify(value))
  | Error(_) => failWith("Expected limited row output")
  }
})

test("ZipExtractor fills null for missing non-required values", () => {
  let out = runSchema(
    ~html="<h2>A</h2><h2>B</h2><span class='p'>1</span>",
    ~schemaRaw="{\"fields\":{\"title\":{\"selector\":\"h2\",\"type\":\"text\"},\"price\":{\"selector\":\".p\",\"type\":\"number\"}}}",
  )
  switch out {
  | Ok(value) => isTextEqualTo("[{\"title\":\"A\",\"price\":1},{\"title\":\"B\",\"price\":null}]", NodeJsBinding.jsonStringify(value))
  | Error(_) => failWith("Expected null fallback in zip mode")
  }
})

test("ZipExtractor returns error for missing required values", () => {
  let out = runSchema(
    ~html="<h2>A</h2><h2>B</h2><span class='p'>1</span>",
    ~schemaRaw="{\"fields\":{\"title\":{\"selector\":\"h2\",\"type\":\"text\"},\"price\":{\"selector\":\".p\",\"type\":\"number\",\"required\":true}}}",
  )
  switch out {
  | Error(RequiredFieldMissing({fieldName, selector})) => {
      isTextEqualTo("price", fieldName)
      isTextEqualTo(".p", selector)
    }
  | _ => failWith("Expected RequiredFieldMissing in zip mode")
  }
})

test("ZipExtractor uses default when ignoreErrors true", () => {
  let out = runSchema(
    ~html="<h2>A</h2><h2>B</h2><span class='p'>1</span>",
    ~schemaRaw="{\"fields\":{\"title\":{\"selector\":\"h2\",\"type\":\"text\"},\"price\":{\"selector\":\".p\",\"type\":\"number\",\"required\":true,\"default\":0}},\"config\":{\"ignoreErrors\":true}}",
  )
  switch out {
  | Ok(value) => isTextEqualTo("[{\"title\":\"A\",\"price\":1},{\"title\":\"B\",\"price\":0}]", NodeJsBinding.jsonStringify(value))
  | Error(_) => failWith("Expected ignoreErrors default behavior in zip mode")
  }
})

test("ZipExtractor repeats aggregate Count/List values per row", () => {
  let out = runSchema(
    ~html="<h2>A</h2><h2>B</h2><span class='tag'>x</span><span class='tag'>y</span><span class='tag'>y</span>",
    ~schemaRaw="{\"fields\":{\"title\":{\"selector\":\"h2\",\"type\":\"text\"},\"totalTags\":{\"selector\":\".tag\",\"type\":\"count\"},\"tags\":{\"selector\":\".tag\",\"type\":\"list\",\"listOptions\":{\"itemType\":\"text\",\"unique\":true}}}}",
  )
  switch out {
  | Ok(value) =>
    isTextEqualTo(
      "[{\"title\":\"A\",\"totalTags\":3,\"tags\":[\"x\",\"y\"]},{\"title\":\"B\",\"totalTags\":3,\"tags\":[\"x\",\"y\"]}]",
      NodeJsBinding.jsonStringify(value),
    )
  | Error(_) => failWith("Expected aggregate values repeated in zip mode")
  }
})

test("ZipExtractor with only aggregate fields returns empty array", () => {
  let out = runSchema(
    ~html="<span class='tag'>x</span><span class='tag'>y</span>",
    ~schemaRaw="{\"fields\":{\"totalTags\":{\"selector\":\".tag\",\"type\":\"count\"},\"tags\":{\"selector\":\".tag\",\"type\":\"list\",\"listOptions\":{\"itemType\":\"text\"}}}}",
  )
  switch out {
  | Ok(value) => isTextEqualTo("[]", NodeJsBinding.jsonStringify(value))
  | Error(_) => failWith("Expected empty output when only aggregate fields exist")
  }
})
