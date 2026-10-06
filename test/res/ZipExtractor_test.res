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

test("ZipExtractor pins required-missing errors when ignoreErrors is false", () => {
  let doc = HtmlFixture.parse("<h2>A</h2><h2>B</h2><span class='p'>1</span>")
  let schema: schema = {
    fields: [
      (
        "title",
        {
          selector: "h2",
          fieldType: Text(None),
          required: false,
        },
      ),
      (
        "price",
        {
          selector: ".p",
          fieldType: Number(None),
          required: true,
        },
      ),
    ],
    config: {
      limit: 0,
      ignoreErrors: false,
    },
  }

  switch ZipExtractor.run(doc, schema) {
  | Error(RequiredFieldMissing({fieldName, selector})) => {
      isTextEqualTo("price", fieldName)
      isTextEqualTo(".p", selector)
    }
  | _ => failWith("Expected RequiredFieldMissing for the second row's missing price")
  }
})

test("ZipExtractor pins required-missing default fallback when ignoreErrors is true", () => {
  let doc = HtmlFixture.parse("<h2>A</h2><h2>B</h2><span class='p'>1</span>")
  let schema: schema = {
    fields: [
      (
        "title",
        {
          selector: "h2",
          fieldType: Text(None),
          required: false,
        },
      ),
      (
        "price",
        {
          selector: ".p",
          fieldType: Number(None),
          required: true,
          default: JSON.Encode.int(0),
        },
      ),
    ],
    config: {
      limit: 0,
      ignoreErrors: true,
    },
  }

  switch ZipExtractor.run(doc, schema) {
  | Ok(json) =>
    isTextEqualTo(
      "[{\"title\":\"A\",\"price\":1},{\"title\":\"B\",\"price\":0}]",
      NodeUtil.jsonStringify(json),
    )
  | Error(_) => failWith("Expected required field default fallback when errors are ignored")
  }
})

test("ZipExtractor returns empty rows when no rows match and ignoreErrors is false", () => {
  let doc = HtmlFixture.parse("<p>No matching rows</p>")
  let schema: schema = {
    fields: [
      (
        "title",
        {
          selector: "h2",
          fieldType: Text(None),
          required: false,
        },
      ),
      (
        "price",
        {
          selector: ".p",
          fieldType: Number(None),
          required: true,
        },
      ),
    ],
    config: {
      limit: 0,
      ignoreErrors: false,
    },
  }

  switch ZipExtractor.run(doc, schema) {
  | Ok(json) => isTextEqualTo("[]", NodeUtil.jsonStringify(json))
  | Error(_) => failWith("Expected no rows to produce an empty result")
  }
})

test("ZipExtractor returns empty rows when no rows match and ignoreErrors is true", () => {
  let doc = HtmlFixture.parse("<p>No matching rows</p>")
  let schema: schema = {
    fields: [
      (
        "title",
        {
          selector: "h2",
          fieldType: Text(None),
          required: false,
        },
      ),
      (
        "price",
        {
          selector: ".p",
          fieldType: Number(None),
          required: true,
          default: JSON.Encode.int(0),
        },
      ),
    ],
    config: {
      limit: 0,
      ignoreErrors: true,
    },
  }

  switch ZipExtractor.run(doc, schema) {
  | Ok(json) => isTextEqualTo("[]", NodeUtil.jsonStringify(json))
  | Error(_) => failWith("Expected no rows to produce an empty result")
  }
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
  | Ok(json) => isTextEqualTo("[]", NodeUtil.jsonStringify(json))
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
    let out = NodeUtil.jsonStringify(json)
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
    let out = NodeUtil.jsonStringify(json)
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
      let jsonArray = TestHelpers.arrayFromJsonString(NodeUtil.jsonStringify(json))
      isIntEqualTo(rowCount, Array.length(jsonArray))
      // Spot-check first and last rows to confirm order preservation.
      let firstStr = NodeUtil.jsonStringify(Array.getUnsafe(jsonArray, 0))
      isTextEqualTo(`{"name":"N0","price":0}`, firstStr)
      let lastStr = NodeUtil.jsonStringify(Array.getUnsafe(jsonArray, rowCount - 1))
      isTextEqualTo(
        `{"name":"N${Int.toString(rowCount - 1)}","price":${Int.toString(rowCount - 1)}}`,
        lastStr,
      )
    }
  | Error(_) => failWith("Expected successful extraction for large dataset")
  }
})
