open Test
open Assertions
open FieldTypes

let getElement = (doc, selector) =>
  switch HtmlFixture.select(doc, selector) {
  | Some(el) => el
  | None => {
      failWith(`Missing element for selector ${selector}`)
      doc
    }
  }

test("ExtractorRegistry uses schema defaults for Text when field opts are absent", () => {
  let doc = HtmlFixture.parse("<div class='v'>  Hello  </div>")
  let el = getElement(doc, ".v")
  let defaults: option<schemaDefaults> = Some({text: {trim: false}})

  switch ExtractorRegistry.extractValue(el, Text(None), defaults, false) {
  | Ok(value) => isTextEqualTo("\"  Hello  \"", NodeUtil.jsonStringify(value))
  | Error(_) => failWith("Expected Text extraction success")
  }
})

test("ExtractorRegistry field options override schema defaults", () => {
  let doc = HtmlFixture.parse("<div class='v'>  Hello  </div>")
  let el = getElement(doc, ".v")
  let defaults: option<schemaDefaults> = Some({text: {trim: false}})

  switch ExtractorRegistry.extractValue(el, Text(Some({trim: true})), defaults, false) {
  | Ok(value) => isTextEqualTo("\"Hello\"", NodeUtil.jsonStringify(value))
  | Error(_) => failWith("Expected Text extraction success")
  }
})

test("ExtractorRegistry extractValueList handles Count", () => {
  let doc = HtmlFixture.parse("<ul><li>A</li><li>B</li><li>C</li></ul>")
  let els = HtmlFixture.selectAll(doc, "li")
  switch ExtractorRegistry.extractValueList(els, Count(None), None, false, false, "count", "li") {
  | Ok(value) => isTextEqualTo("3", NodeUtil.jsonStringify(value))
  | Error(_) => failWith("Expected Count extraction success")
  }
})

test("ExtractorRegistry extractValueList handles List", () => {
  let doc = HtmlFixture.parse("<ul><li>A</li><li>B</li></ul>")
  let els = HtmlFixture.selectAll(doc, "li")
  let opts: listOptions = {itemType: ListText}
  switch ExtractorRegistry.extractValueList(els, List(opts), None, false, false, "items", "li") {
  | Ok(value) => isTextEqualTo("[\"A\",\"B\"]", NodeUtil.jsonStringify(value))
  | Error(_) => failWith("Expected List extraction success")
  }
})

test("ExtractorRegistry extractValueList scalar fallback uses first element", () => {
  let doc = HtmlFixture.parse("<h2>A</h2><h2>B</h2>")
  let els = HtmlFixture.selectAll(doc, "h2")
  switch ExtractorRegistry.extractValueList(els, Text(None), None, false, false, "title", "h2") {
  | Ok(value) => isTextEqualTo("\"A\"", NodeUtil.jsonStringify(value))
  | Error(_) => failWith("Expected scalar fallback extraction success")
  }
})

test(
  "ExtractorRegistry extractValueList returns RequiredFieldMissing for required Count with empty elements",
  () => {
    let els = []
    switch ExtractorRegistry.extractValueList(
      els,
      Count(None),
      None,
      false,
      true,
      "items",
      ".item",
    ) {
    | Error(RequiredFieldMissing({fieldName, selector})) => {
        isTextEqualTo("items", fieldName)
        isTextEqualTo(".item", selector)
      }
    | _ => failWith("Expected RequiredFieldMissing for required Count with empty elements")
    }
  },
)

test(
  "ExtractorRegistry extractValueList returns RequiredFieldMissing for required List with empty elements",
  () => {
    let els = []
    let opts: listOptions = {itemType: ListText}
    switch ExtractorRegistry.extractValueList(els, List(opts), None, false, true, "tags", ".tag") {
    | Error(RequiredFieldMissing({fieldName, selector})) => {
        isTextEqualTo("tags", fieldName)
        isTextEqualTo(".tag", selector)
      }
    | _ => failWith("Expected RequiredFieldMissing for required List with empty elements")
    }
  },
)

test(
  "ExtractorRegistry extractValueList returns 0 for non-required Count with empty elements",
  () => {
    let els = []
    switch ExtractorRegistry.extractValueList(
      els,
      Count(None),
      None,
      false,
      false,
      "items",
      ".item",
    ) {
    | Ok(value) => isTextEqualTo("0", NodeUtil.jsonStringify(value))
    | Error(_) => failWith("Expected Count=0 for non-required field with empty elements")
    }
  },
)

test("ExtractorRegistry extractValueOrAbsent returns false for Boolean Presence", () => {
  switch ExtractorRegistry.extractValueOrAbsent(
    None,
    Boolean(Some({mode: Presence})),
    None,
    true,
    "available",
    ".flag",
    None,
    false,
  ) {
  | Ok(value) => isTextEqualTo("false", NodeUtil.jsonStringify(value))
  | Error(_) => failWith("Expected Presence=false for missing element")
  }
})

test("ExtractorRegistry extractValueOrAbsent returns RequiredFieldMissing", () => {
  switch ExtractorRegistry.extractValueOrAbsent(
    None,
    Number(None),
    None,
    true,
    "price",
    ".price",
    None,
    false,
  ) {
  | Error(RequiredFieldMissing({fieldName, selector})) => {
      isTextEqualTo("price", fieldName)
      isTextEqualTo(".price", selector)
    }
  | _ => failWith("Expected RequiredFieldMissing")
  }
})

test("ExtractorRegistry extractValueOrAbsent uses default fallback", () => {
  switch ExtractorRegistry.extractValueOrAbsent(
    None,
    Number(None),
    Some(JSON.Encode.int(0)),
    true,
    "price",
    ".price",
    None,
    true,
  ) {
  | Ok(value) => isTextEqualTo("0", NodeUtil.jsonStringify(value))
  | Error(_) => failWith("Expected default fallback value")
  }
})

test("ExtractorRegistry propagates extractor errors", () => {
  let doc = HtmlFixture.parse("<div class='v'>maybe</div>")
  let el = getElement(doc, ".v")
  switch ExtractorRegistry.extractValue(el, Boolean(Some({onUnknown: UnknownError})), None, false) {
  | Error(ExtractionError(_)) => passWith("error propagated")
  | _ => failWith("Expected boolean UnknownError propagation")
  }
})

test("ExtractorRegistry extractValue supports Table field", () => {
  let doc = HtmlFixture.parse(
    "<table class='t'><tbody><tr><td class='name'>A</td></tr><tr><td class='name'>B</td></tr></tbody></table>",
  )
  let tableEl = getElement(doc, "table.t")
  let columns: array<columnField> = [
    {
      name: "name",
      selector: ".name",
      columnType: ColumnText(None),
      required: false,
    },
  ]
  let tableOpts: tableOptions = {columns: columns}

  switch ExtractorRegistry.extractValue(tableEl, Table(tableOpts), None, false) {
  | Ok(value) => isTextEqualTo("[{\"name\":\"A\"},{\"name\":\"B\"}]", NodeUtil.jsonStringify(value))
  | Error(_) => failWith("Expected table extraction success")
  }
})

test("ExtractorRegistry table columns honor required error behavior", () => {
  let doc = HtmlFixture.parse(
    "<table class='t'><tbody><tr><td class='name'>A</td></tr></tbody></table>",
  )
  let tableEl = getElement(doc, "table.t")
  let columns: array<columnField> = [
    {
      name: "price",
      selector: ".price",
      columnType: ColumnNumber(None),
      required: true,
    },
  ]
  let tableOpts: tableOptions = {columns: columns}

  switch ExtractorRegistry.extractValue(tableEl, Table(tableOpts), None, false) {
  | Error(RequiredFieldMissing({fieldName, selector})) => {
      isTextEqualTo("price", fieldName)
      isTextEqualTo(".price", selector)
    }
  | _ => failWith("Expected RequiredFieldMissing for table column")
  }
})

/* -------------------------------------------------------------------------- */
/* Separated Table Extraction — pin down the exact JSON output of the */
/* embedded table logic so the refactor into TableFieldExtractor.res cannot */
/* silently change row/column output. */
/* -------------------------------------------------------------------------- */

test("ExtractorRegistry table with multiple columns produces expected row objects", () => {
  let doc = HtmlFixture.parse(
    "<table class='t'><tbody><tr><td class='name'>A</td><td class='price'>10</td></tr><tr><td class='name'>B</td><td class='price'>20</td></tr></tbody></table>",
  )
  let tableEl = getElement(doc, "table.t")
  let columns: array<columnField> = [
    {name: "name", selector: ".name", columnType: ColumnText(None), required: false},
    {name: "price", selector: ".price", columnType: ColumnText(None), required: false},
  ]
  let tableOpts: tableOptions = {columns: columns}

  switch ExtractorRegistry.extractValue(tableEl, Table(tableOpts), None, false) {
  | Ok(value) =>
    isTextEqualTo(
      "[{\"name\":\"A\",\"price\":\"10\"},{\"name\":\"B\",\"price\":\"20\"}]",
      NodeUtil.jsonStringify(value),
    )
  | Error(_) => failWith("Expected table extraction success")
  }
})

test("ExtractorRegistry table with custom rowSelector extracts those rows", () => {
  /* Container <section> holds three <article class='row'> children; rowSelector
     ".row" is resolved relative to the container element, then the column
     selector ".label" runs INSIDE each row. */
  let doc = HtmlFixture.parse(
    "<section><article class='row'><span class='label'>R1</span></article><article class='row'><span class='label'>R2</span></article><article class='row'><span class='label'>R3</span></article></section>",
  )
  let containerEl = getElement(doc, "section")
  let columns: array<columnField> = [
    {name: "label", selector: ".label", columnType: ColumnText(None), required: false},
  ]
  let tableOpts: tableOptions = {rowSelector: ".row", columns}

  switch ExtractorRegistry.extractValue(containerEl, Table(tableOpts), None, false) {
  | Ok(value) =>
    isTextEqualTo(
      "[{\"label\":\"R1\"},{\"label\":\"R2\"},{\"label\":\"R3\"}]",
      NodeUtil.jsonStringify(value),
    )
  | Error(_) => failWith("Expected custom rowSelector extraction")
  }
})

test("ExtractorRegistry table without tbody falls back to skipping first tr (thead)", () => {
  /* No <tbody> → falls back to all tr, skips first one (the header). */
  let doc = HtmlFixture.parse(
    "<table class='t'><tr><th>X</th></tr><tr><td class='name'>A</td></tr><tr><td class='name'>B</td></tr></table>",
  )
  let tableEl = getElement(doc, "table.t")
  let columns: array<columnField> = [
    {name: "name", selector: ".name", columnType: ColumnText(None), required: false},
  ]
  let tableOpts: tableOptions = {columns: columns}

  switch ExtractorRegistry.extractValue(tableEl, Table(tableOpts), None, false) {
  | Ok(value) => isTextEqualTo("[{\"name\":\"A\"},{\"name\":\"B\"}]", NodeUtil.jsonStringify(value))
  | Error(_) => failWith("Expected thead fallback extraction")
  }
})

test("ExtractorRegistry table with single tr and no tbody yields empty rows", () => {
  /* Without tbody, only 1 tr → empty array (treated as header-only table). */
  let doc = HtmlFixture.parse("<table class='t'><tr><th>X</th></tr></table>")
  let tableEl = getElement(doc, "table.t")
  let columns: array<columnField> = [
    {name: "name", selector: ".name", columnType: ColumnText(None), required: false},
  ]
  let tableOpts: tableOptions = {columns: columns}

  switch ExtractorRegistry.extractValue(tableEl, Table(tableOpts), None, false) {
  | Ok(value) => isTextEqualTo("[]", NodeUtil.jsonStringify(value))
  | Error(_) => failWith("Expected empty rows fallback")
  }
})

test("ExtractorRegistry table with required column uses default fallback", () => {
  let doc = HtmlFixture.parse(
    "<table class='t'><tbody><tr><td class='name'>A</td></tr></tbody></table>",
  )
  let tableEl = getElement(doc, "table.t")
  let columns: array<columnField> = [
    {
      name: "price",
      selector: ".price",
      columnType: ColumnNumber(None),
      required: true,
      default: JSON.Encode.float(0.0),
    },
  ]
  let tableOpts: tableOptions = {columns: columns}

  switch ExtractorRegistry.extractValue(tableEl, Table(tableOpts), None, true) {
  | Ok(value) => isTextEqualTo("[{\"price\":0}]", NodeUtil.jsonStringify(value))
  | Error(_) => failWith("Expected default fallback for missing column")
  }
})

test("ExtractorRegistry table ignoreErrors true suppresses column error", () => {
  let doc = HtmlFixture.parse(
    "<table class='t'><tbody><tr><td class='name'>A</td></tr></tbody></table>",
  )
  let tableEl = getElement(doc, "table.t")
  let columns: array<columnField> = [
    {
      name: "stock",
      selector: ".stock",
      columnType: ColumnBoolean(Some({onUnknown: UnknownError})),
      required: true,
    },
  ]
  let tableOpts: tableOptions = {columns: columns}

  /* ignoreErrors=true should swallow the ExtractionError and return null. */
  switch ExtractorRegistry.extractValue(tableEl, Table(tableOpts), None, true) {
  | Ok(value) => isTextEqualTo("[{\"stock\":null}]", NodeUtil.jsonStringify(value))
  | Error(_) => failWith("Expected ignoreErrors to swallow error")
  }
})

test("ExtractorRegistry table list column extracts element array per row", () => {
  let doc = HtmlFixture.parse(
    "<table class='t'><tbody><tr><td class='tag'><span>1</span><span>2</span></td></tr><tr><td class='tag'><span>3</span></td></tr></tbody></table>",
  )
  let tableEl = getElement(doc, "table.t")
  let columns: array<columnField> = [
    {
      name: "tags",
      selector: ".tag span",
      columnType: ColumnList({itemType: ListText}),
      required: false,
    },
  ]
  let tableOpts: tableOptions = {columns: columns}

  switch ExtractorRegistry.extractValue(tableEl, Table(tableOpts), None, false) {
  | Ok(value) =>
    isTextEqualTo("[{\"tags\":[\"1\",\"2\"]},{\"tags\":[\"3\"]}]", NodeUtil.jsonStringify(value))
  | Error(_) => failWith("Expected list column extraction")
  }
})

test("ExtractorRegistry table with empty tbody yields empty array", () => {
  let doc = HtmlFixture.parse("<table class='t'><tbody></tbody></table>")
  let tableEl = getElement(doc, "table.t")
  let columns: array<columnField> = [
    {name: "name", selector: ".name", columnType: ColumnText(None), required: false},
  ]
  let tableOpts: tableOptions = {columns: columns}

  switch ExtractorRegistry.extractValue(tableEl, Table(tableOpts), None, false) {
  | Ok(value) => isTextEqualTo("[]", NodeUtil.jsonStringify(value))
  | Error(_) => failWith("Expected empty tbody to yield []")
  }
})
