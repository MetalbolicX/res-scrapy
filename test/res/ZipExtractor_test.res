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

test("ZipExtractor - run with multiple rows preserves order and count", () => {
  let html = `<html><body>
    <span class="name">A</span>
    <span class="name">B</span>
    <span class="name">C</span>
    <span class="price">10</span>
    <span class="price">20</span>
    <span class="price">30</span>
  </body></html>`
  let doc = HtmlFixture.parse(html)
  let schema: schema = {
    fields: [
      (
        "name",
        {
          selector: ".name",
          fieldType: Text(None),
          required: false,
        },
      ),
      (
        "price",
        {
          selector: ".price",
          fieldType: Number(None),
          required: false,
        },
      ),
    ],
    config: {
      limit: 0,
      ignoreErrors: false,
    },
  }

  let result = ZipExtractor.run(doc, schema)
  isResultOk(result)
  switch result {
  | Ok(json) =>
    let out = NodeJsBinding.jsonStringify(json)
    isTextEqualTo(`[{"name":"A","price":10},{"name":"B","price":20},{"name":"C","price":30}]`, out)
  | Error(_) => failWith("Expected successful multi-row extraction")
  }
})

test("ZipExtractor - limit config caps row count", () => {
  let html = `<html><body>
    <span class="name">A</span>
    <span class="name">B</span>
    <span class="name">C</span>
    <span class="price">10</span>
    <span class="price">20</span>
    <span class="price">30</span>
  </body></html>`
  let doc = HtmlFixture.parse(html)
  let schema: schema = {
    fields: [
      (
        "name",
        {
          selector: ".name",
          fieldType: Text(None),
          required: false,
        },
      ),
      (
        "price",
        {
          selector: ".price",
          fieldType: Number(None),
          required: false,
        },
      ),
    ],
    config: {
      limit: 2,
      ignoreErrors: false,
    },
  }

  let result = ZipExtractor.run(doc, schema)
  isResultOk(result)
  switch result {
  | Ok(json) =>
    let out = NodeJsBinding.jsonStringify(json)
    isTextEqualTo(`[{"name":"A","price":10},{"name":"B","price":20}]`, out)
  | Error(_) => failWith("Expected successful extraction with limit")
  }
})

test("ZipExtractor - handles large row count without stack overflow", () => {
  // Builds a document with 5000 elements per field; iterative conversion
  // must produce identical JSON to the prior recursive implementation.
  let rowCount = 5000
  let htmlBuilder = ref("<html><body>")
  for i in 0 to rowCount - 1 {
    htmlBuilder := htmlBuilder.contents ++ `<span class="name">N${Int.toString(i)}</span>`
    htmlBuilder := htmlBuilder.contents ++ `<span class="price">${Int.toString(i)}</span>`
  }
  let html = htmlBuilder.contents ++ "</body></html>"
  let doc = HtmlFixture.parse(html)
  let schema: schema = {
    fields: [
      (
        "name",
        {
          selector: ".name",
          fieldType: Text(None),
          required: false,
        },
      ),
      (
        "price",
        {
          selector: ".price",
          fieldType: Number(None),
          required: false,
        },
      ),
    ],
    config: {
      limit: 0,
      ignoreErrors: false,
    },
  }

  let result = ZipExtractor.run(doc, schema)
  isResultOk(result)
  switch result {
  | Ok(json) => {
      let jsonArray = TestHelpers.arrayFromJsonString(NodeJsBinding.jsonStringify(json))
      isIntEqualTo(rowCount, Array.length(jsonArray))
      // Spot-check first and last rows to confirm order preservation.
      let firstStr = NodeJsBinding.jsonStringify(Array.getUnsafe(jsonArray, 0))
      isTextEqualTo(`{"name":"N0","price":0}`, firstStr)
      let lastStr = NodeJsBinding.jsonStringify(Array.getUnsafe(jsonArray, rowCount - 1))
      isTextEqualTo(
        `{"name":"N${Int.toString(rowCount - 1)}","price":${Int.toString(rowCount - 1)}}`,
        lastStr,
      )
    }
  | Error(_) => failWith("Expected successful extraction for large dataset")
  }
})
