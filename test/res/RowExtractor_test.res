open Test
open Assertions
open FieldTypes

test("RowExtractor - Strategy metadata is correct", () => {
  isTextEqualTo("row", RowExtractor.Strategy.name)

  let schemaNoRow: schema = {
    fields: [],
    config: {
      limit: 0,
      ignoreErrors: false,
    },
  }

  let schemaWithRow: schema = {
    fields: [],
    config: {
      rowSelector: ".row",
      limit: 0,
      ignoreErrors: false,
    },
  }

  isTruthy(RowExtractor.Strategy.canHandle(schemaNoRow) == false)
  isTruthy(RowExtractor.Strategy.canHandle(schemaWithRow) == true)
})

test("RowExtractor - run with empty fields returns array of empty objects for each row", () => {
  let doc = HtmlFixture.parse("<div class='r'>A</div><div class='r'>B</div>")
  let schema: schema = {
    fields: [],
    config: {
      rowSelector: ".r",
      limit: 0,
      ignoreErrors: false,
    },
  }

  let result = RowExtractor.run(doc, schema)
  isResultOk(result)
  switch result {
  | Ok(json) => isTextEqualTo("[{},{}]", NodeJsBinding.jsonStringify(json))
  | Error(_) => failWith("Expected array of empty objects")
  }
})
