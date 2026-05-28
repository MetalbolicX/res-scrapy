open Test
open Assertions
open FieldTypes

test("ZipExtractor - Strategy metadata is correct", () => {
  isTextEqualTo("zip", ZipExtractor.Strategy.name)

  let schema: schema = {
    fields: [],
    config: {
      limit: 0,
      ignoreErrors: false,
    },
  }

  isTruthy(ZipExtractor.Strategy.canHandle(schema) == true)
})

test("ZipExtractor - run with empty fields returns zero rows", () => {
  let doc = HtmlFixture.parse("<div>A</div>")
  let schema: schema = {
    fields: [],
    config: {
      limit: 0,
      ignoreErrors: false,
    },
  }

  let result = ZipExtractor.run(doc, schema)
  isResultOk(result)
  switch result {
  | Ok(json) => isTextEqualTo("[]", NodeJsBinding.jsonStringify(json))
  | Error(_) => failWith("Expected empty array")
  }
})
