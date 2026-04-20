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
  | Ok(value) => isTextEqualTo("\"  Hello  \"", NodeJsBinding.jsonStringify(value))
  | Error(_) => failWith("Expected Text extraction success")
  }
})

test("ExtractorRegistry field options override schema defaults", () => {
  let doc = HtmlFixture.parse("<div class='v'>  Hello  </div>")
  let el = getElement(doc, ".v")
  let defaults: option<schemaDefaults> = Some({text: {trim: false}})

  switch ExtractorRegistry.extractValue(el, Text(Some({trim: true})), defaults, false) {
  | Ok(value) => isTextEqualTo("\"Hello\"", NodeJsBinding.jsonStringify(value))
  | Error(_) => failWith("Expected Text extraction success")
  }
})

test("ExtractorRegistry extractValueList handles Count", () => {
  let doc = HtmlFixture.parse("<ul><li>A</li><li>B</li><li>C</li></ul>")
  let els = HtmlFixture.selectAll(doc, "li")
  switch ExtractorRegistry.extractValueList(els, Count(None), None, false, false, "count", "li") {
  | Ok(value) => isTextEqualTo("3", NodeJsBinding.jsonStringify(value))
  | Error(_) => failWith("Expected Count extraction success")
  }
})

test("ExtractorRegistry extractValueList handles List", () => {
  let doc = HtmlFixture.parse("<ul><li>A</li><li>B</li></ul>")
  let els = HtmlFixture.selectAll(doc, "li")
  let opts: listOptions = {itemType: ListText}
  switch ExtractorRegistry.extractValueList(els, List(opts), None, false, false, "items", "li") {
  | Ok(value) => isTextEqualTo("[\"A\",\"B\"]", NodeJsBinding.jsonStringify(value))
  | Error(_) => failWith("Expected List extraction success")
  }
})

test("ExtractorRegistry extractValueList scalar fallback uses first element", () => {
  let doc = HtmlFixture.parse("<h2>A</h2><h2>B</h2>")
  let els = HtmlFixture.selectAll(doc, "h2")
  switch ExtractorRegistry.extractValueList(els, Text(None), None, false, false, "title", "h2") {
  | Ok(value) => isTextEqualTo("\"A\"", NodeJsBinding.jsonStringify(value))
  | Error(_) => failWith("Expected scalar fallback extraction success")
  }
})

test("ExtractorRegistry extractValueList returns RequiredFieldMissing for required Count with empty elements", () => {
  let els = []
  switch ExtractorRegistry.extractValueList(els, Count(None), None, false, true, "items", ".item") {
  | Error(RequiredFieldMissing({fieldName, selector})) => {
      isTextEqualTo("items", fieldName)
      isTextEqualTo(".item", selector)
    }
  | _ => failWith("Expected RequiredFieldMissing for required Count with empty elements")
  }
})

test("ExtractorRegistry extractValueList returns RequiredFieldMissing for required List with empty elements", () => {
  let els = []
  let opts: listOptions = {itemType: ListText}
  switch ExtractorRegistry.extractValueList(els, List(opts), None, false, true, "tags", ".tag") {
  | Error(RequiredFieldMissing({fieldName, selector})) => {
      isTextEqualTo("tags", fieldName)
      isTextEqualTo(".tag", selector)
    }
  | _ => failWith("Expected RequiredFieldMissing for required List with empty elements")
  }
})

test("ExtractorRegistry extractValueList returns 0 for non-required Count with empty elements", () => {
  let els = []
  switch ExtractorRegistry.extractValueList(els, Count(None), None, false, false, "items", ".item") {
  | Ok(value) => isTextEqualTo("0", NodeJsBinding.jsonStringify(value))
  | Error(_) => failWith("Expected Count=0 for non-required field with empty elements")
  }
})

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
  | Ok(value) => isTextEqualTo("false", NodeJsBinding.jsonStringify(value))
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
  | Ok(value) => isTextEqualTo("0", NodeJsBinding.jsonStringify(value))
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
  let columns: array<columnField> = [{
    name: "name",
    selector: ".name",
    columnType: ColumnText(None),
    required: false,
  }]
  let tableOpts: tableOptions = {columns: columns}

  switch ExtractorRegistry.extractValue(tableEl, Table(tableOpts), None, false) {
  | Ok(value) =>
    isTextEqualTo("[{\"name\":\"A\"},{\"name\":\"B\"}]", NodeJsBinding.jsonStringify(value))
  | Error(_) => failWith("Expected table extraction success")
  }
})

test("ExtractorRegistry table columns honor required error behavior", () => {
  let doc = HtmlFixture.parse("<table class='t'><tbody><tr><td class='name'>A</td></tr></tbody></table>")
  let tableEl = getElement(doc, "table.t")
  let columns: array<columnField> = [{
    name: "price",
    selector: ".price",
    columnType: ColumnNumber(None),
    required: true,
  }]
  let tableOpts: tableOptions = {columns: columns}

  switch ExtractorRegistry.extractValue(tableEl, Table(tableOpts), None, false) {
  | Error(RequiredFieldMissing({fieldName, selector})) => {
      isTextEqualTo("price", fieldName)
      isTextEqualTo(".price", selector)
    }
  | _ => failWith("Expected RequiredFieldMissing for table column")
  }
})
