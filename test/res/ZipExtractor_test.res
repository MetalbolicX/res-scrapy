open Test
open Assertions
open FieldTypes

test("zip absent Presence preserves defaults, modes and required gates", () => {
  [
    (
      "<i>A</i><i>B</i><b class='badge'></b>",
      "presence",
      "",
      false,
      false,
      "[{\"i\":\"A\",\"badge\":true},{\"i\":\"B\",\"badge\":false}]",
    ),
    (
      "<i>A</i><i>B</i>",
      "presence",
      "",
      false,
      false,
      "[{\"i\":\"A\",\"badge\":false},{\"i\":\"B\",\"badge\":false}]",
    ),
    (
      "<i>A</i><i>B</i>",
      "presence",
      ",\"default\":true",
      false,
      false,
      "[{\"i\":\"A\",\"badge\":true},{\"i\":\"B\",\"badge\":true}]",
    ),
    (
      "<i>A</i><i>B</i>",
      "presence",
      ",\"default\":null",
      false,
      false,
      "[{\"i\":\"A\",\"badge\":null},{\"i\":\"B\",\"badge\":null}]",
    ),
    (
      "<i>A</i><i>B</i>",
      "mapping",
      "",
      false,
      false,
      "[{\"i\":\"A\",\"badge\":null},{\"i\":\"B\",\"badge\":null}]",
    ),
    (
      "<i>A</i><i>B</i>",
      "attributeCheck",
      "",
      false,
      false,
      "[{\"i\":\"A\",\"badge\":null},{\"i\":\"B\",\"badge\":null}]",
    ),
    (
      "<i>A</i><i>B</i>",
      "presence",
      "",
      true,
      true,
      "[{\"i\":\"A\",\"badge\":false},{\"i\":\"B\",\"badge\":false}]",
    ),
    (
      "<i>A</i><i>B</i>",
      "presence",
      ",\"default\":true",
      true,
      true,
      "[{\"i\":\"A\",\"badge\":true},{\"i\":\"B\",\"badge\":true}]",
    ),
    ("<p>none</p>", "presence", "", true, false, "[]"),
  ]->Array.forEach(((html, mode, fallback, required, ignoreErrors, expected)) => {
    let raw = `{"config":{"ignoreErrors":${Bool.toString(
        ignoreErrors,
      )},"defaults":{"boolean":{"mode":"${mode}"}}},"fields":{"i":{"selector":"i"},"badge":{"selector":".badge","type":"boolean","required":${Bool.toString(
        required,
      )}${fallback}}}}`
    switch SchemaParser.parseSchema(TestHelpers.objectFromJsonString(raw)) {
    | Ok(schema) =>
      switch ZipExtractor.run(HtmlFixture.parse(html), schema) {
      | Ok(value) => isTextEqualTo(expected, NodeUtil.jsonStringify(value))
      | Error(_) => failWith("Expected Presence output")
      }
    | Error(_) => failWith("Expected Presence schema")
    }
  })
  let schema: schema = {
    fields: [
      ("i", {selector: "i", fieldType: Text(None), required: false}),
      (
        "badge",
        {
          selector: ".badge",
          fieldType: Boolean(Some({mode: Presence})),
          required: true,
          default: JSON.Encode.bool(true),
        },
      ),
    ],
    config: {limit: 0, ignoreErrors: false},
  }
  switch ZipExtractor.run(HtmlFixture.parse("<i>A</i>"), schema) {
  | Error(RequiredFieldMissing({fieldName, selector})) => {
      isTextEqualTo("badge", fieldName)
      isTextEqualTo(".badge", selector)
    }
  | _ => failWith("Expected required Presence error before default")
  }
})

test("zip maximum preserves unequal selectors, order, defaults and limits", () => {
  let i: (string, schemaField) = ("i", {selector: "i", fieldType: Text(None), required: false})
  let s: (string, schemaField) = ("s", {selector: "s", fieldType: Text(None), required: false})
  let missing: (string, schemaField) = (
    "i",
    {selector: "u", fieldType: Text(None), required: false},
  )
  let fallback: (string, schemaField) = (
    "i",
    {selector: "u", fieldType: Text(None), required: false, default: JSON.Encode.string("D")},
  )
  [
    ([i, s], 0, "[{\"i\":\"I\",\"s\":\"A\"},{\"i\":null,\"s\":\"B\"}]"),
    ([s, i], 0, "[{\"s\":\"A\",\"i\":\"I\"},{\"s\":\"B\",\"i\":null}]"),
    ([missing, s], 0, "[{\"i\":null,\"s\":\"A\"},{\"i\":null,\"s\":\"B\"}]"),
    ([fallback, s], 0, "[{\"i\":\"D\",\"s\":\"A\"},{\"i\":\"D\",\"s\":\"B\"}]"),
    ([i, s], 1, "[{\"i\":\"I\",\"s\":\"A\"}]"),
  ]->Array.forEach(((fields, limit, expected)) => {
    let schema: schema = {fields, config: {limit, ignoreErrors: false}}
    switch ZipExtractor.run(HtmlFixture.parse("<i>I</i><s>A</s><s>B</s>"), schema) {
    | Ok(value) => isTextEqualTo(expected, NodeUtil.jsonStringify(value))
    | Error(_) => failWith("Expected maximum zip output")
    }
  })
})

test("zip joined text standalone and broadcast boundaries", () => {
  let joined: (string, schemaField) = (
    "t",
    {selector: "span", fieldType: Text(Some({join: "|"})), required: false},
  )
  let scalar: (string, schemaField) = ("i", {selector: "i", fieldType: Text(None), required: false})
  let cases = [
    ("<span>A</span><span>B</span>", [joined], "[{\"t\":\"A|B\"}]"),
    (
      "<i>I</i><i>J</i><span>A</span><span>B</span>",
      [scalar, joined],
      "[{\"i\":\"I\",\"t\":\"A|B\"},{\"i\":\"J\",\"t\":\"A|B\"}]",
    ),
    ("", [joined], "[]"),
    ("<span>A</span>", [scalar, joined], "[]"),
    ("<i>I</i>", [scalar, joined], "[{\"i\":\"I\",\"t\":null}]"),
    ("<span> </span>", [joined], "[{\"t\":null}]"),
    (
      "<span>A</span><span>B</span>",
      [
        ("c", {selector: "span", fieldType: Count(None), required: false}),
        ("l", {selector: "span", fieldType: List({itemType: ListText}), required: false}),
      ],
      "[]",
    ),
    ("<i>A</i><i>B</i>", [scalar], "[{\"i\":\"A\"},{\"i\":\"B\"}]"),
  ]
  cases->Array.forEach(((html, fields, expected)) => {
    let schema: schema = {fields, config: {limit: 0, ignoreErrors: false}}
    switch ZipExtractor.run(HtmlFixture.parse(html), schema) {
    | Ok(value) => isTextEqualTo(expected, NodeUtil.jsonStringify(value))
    | Error(_) => failWith("Expected zip output")
    }
  })
})

test("zip join miss inside rows keeps the joined field null in every row", () => {
  let i: (string, schemaField) = ("i", {selector: "i", fieldType: Text(None), required: false})
  let joined: (string, schemaField) = (
    "t",
    {selector: "span", fieldType: Text(Some({join: "|"})), required: false},
  )
  let schema: schema = {fields: [i, joined], config: {limit: 0, ignoreErrors: false}}
  switch ZipExtractor.run(HtmlFixture.parse("<i>I</i><i>J</i>"), schema) {
  | Ok(value) =>
    isTextEqualTo(
      "[{\"i\":\"I\",\"t\":null},{\"i\":\"J\",\"t\":null}]",
      NodeUtil.jsonStringify(value),
    )
  | Error(_) => failWith("Expected zip rows with a null joined field")
  }
})

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
