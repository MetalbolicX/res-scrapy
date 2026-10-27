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

let mkCtx = (
  ~defaults: option<schemaDefaults>,
  ~ignoreErrors=false,
  ~required=false,
  ~fieldName="root",
  ~selector=".",
): extractContext => {defaults, ignoreErrors, required, fieldName, selector}

test("ColumnHtml extracts inner HTML from a table cell", () => {
  let doc = HtmlFixture.parse(
    "<table class='t'><tbody><tr><td class='c'><b>bold</b> text</td></tr></tbody></table>",
  )
  let tableEl = getElement(doc, "table.t")
  let columns: array<columnField> = [
    {name: "x", selector: ".c", columnType: ColumnHtml(None), required: false},
  ]
  let tableOpts: tableOptions = {columns: columns}
  switch ExtractorRegistry.extractValue(
    tableEl,
    Table(tableOpts),
    mkCtx(~defaults=None, ~ignoreErrors=false),
  ) {
  | Ok(value) => isTextEqualTo("[{\"x\":\"<b>bold</b> text\"}]", NodeUtil.jsonStringify(value))
  | Error(_) => failWith("Expected ColumnHtml extraction success")
  }
})

test("ColumnAttribute extracts href from table cell", () => {
  let doc = HtmlFixture.parse(
    "<table class='t'><tbody><tr><td class='c' href=\"/p\">L</td></tr></tbody></table>",
  )
  let tableEl = getElement(doc, "table.t")
  let columns: array<columnField> = [
    {
      name: "x",
      selector: ".c",
      columnType: ColumnAttribute({names: ["href"], mode: First}),
      required: false,
    },
  ]
  let tableOpts: tableOptions = {columns: columns}
  switch ExtractorRegistry.extractValue(
    tableEl,
    Table(tableOpts),
    mkCtx(~defaults=None, ~ignoreErrors=false),
  ) {
  | Ok(value) => isTextEqualTo("[{\"x\":\"/p\"}]", NodeUtil.jsonStringify(value))
  | Error(_) => failWith("Expected ColumnAttribute extraction success")
  }
})

test("ColumnUrl extracts href from table cell", () => {
  let doc = HtmlFixture.parse(
    "<table class='t'><tbody><tr><td class='c' href=\"http://example.com/u\">L</td></tr></tbody></table>",
  )
  let tableEl = getElement(doc, "table.t")
  let columns: array<columnField> = [
    {name: "x", selector: ".c", columnType: ColumnUrl(None), required: false},
  ]
  let tableOpts: tableOptions = {columns: columns}
  switch ExtractorRegistry.extractValue(
    tableEl,
    Table(tableOpts),
    mkCtx(~defaults=None, ~ignoreErrors=false),
  ) {
  | Ok(value) => isTextEqualTo("[{\"x\":\"http://example.com/u\"}]", NodeUtil.jsonStringify(value))
  | Error(_) => failWith("Expected ColumnUrl extraction success")
  }
})

test("ColumnJson parses JSON text from table cell", () => {
  let doc = HtmlFixture.parse(
    "<table class='t'><tbody><tr><td class='c'>{\"a\":1}</td></tr></tbody></table>",
  )
  let tableEl = getElement(doc, "table.t")
  let columns: array<columnField> = [
    {name: "x", selector: ".c", columnType: ColumnJson(None), required: false},
  ]
  let tableOpts: tableOptions = {columns: columns}
  switch ExtractorRegistry.extractValue(
    tableEl,
    Table(tableOpts),
    mkCtx(~defaults=None, ~ignoreErrors=false),
  ) {
  | Ok(value) => isTextEqualTo("[{\"x\":{\"a\":1}}]", NodeUtil.jsonStringify(value))
  | Error(_) => failWith("Expected ColumnJson extraction success")
  }
})

test("ColumnDateTime parses ISO date text from table cell", () => {
  let doc = HtmlFixture.parse(
    "<table class='t'><tbody><tr><td class='c'>2024-01-15</td></tr></tbody></table>",
  )
  let tableEl = getElement(doc, "table.t")
  let columns: array<columnField> = [
    {name: "x", selector: ".c", columnType: ColumnDateTime(None), required: false},
  ]
  let tableOpts: tableOptions = {columns: columns}
  switch ExtractorRegistry.extractValue(
    tableEl,
    Table(tableOpts),
    mkCtx(~defaults=None, ~ignoreErrors=false),
  ) {
  | Ok(value) => NodeUtil.jsonStringify(value)->TestHelpers.stringContains("2024-01-15")->isTruthy
  | Error(_) => failWith("Expected ColumnDateTime extraction success")
  }
})

test("ColumnDefaults resolve each column type to its schema default options", () => {
  let defaults: option<schemaDefaults> = Some({
    text: {},
    html: {},
    url: {},
    datetime: {},
  })
  let resolve = col =>
    DefaultsMerger.resolveDefaults(defaults, TableFieldExtractor.columnTypeToFieldType(col))
  isTruthy(resolve(ColumnText(None)) == Text(Some({})), ~message="ColumnText")
  isTruthy(resolve(ColumnHtml(None)) == Html(Some({})), ~message="ColumnHtml")
  isTruthy(resolve(ColumnUrl(None)) == Url(Some({})), ~message="ColumnUrl")
  // The fixture has no json default, so JSON options stay absent.
  isTruthy(resolve(ColumnJson(None)) == Json(None), ~message="ColumnJson")
  isTruthy(resolve(ColumnDateTime(None)) == DateTime(Some({})), ~message="ColumnDateTime")
})
