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

let extractTable = (~ignoreErrors, ~default: option<JSON.t>) => {
  let doc = HtmlFixture.parse(
    "<table class='t'><tbody><tr><td class='stock'>not-a-boolean</td></tr></tbody></table>",
  )
  let tableEl = getElement(doc, "table.t")
  let columns: array<columnField> = [
    {
      name: "stock",
      selector: ".stock",
      columnType: ColumnBoolean(Some({onUnknown: UnknownError})),
      required: false,
      ?default,
    },
  ]
  TableFieldExtractor.extract(
    tableEl,
    {columns: columns},
    {
      defaults: None,
      ignoreErrors,
      required: false,
      fieldName: "table",
      selector: "table.t",
    },
    ExtractorRegistry.extractValue,
  )
}

test("TableFieldExtractor propagates a cell extraction error when ignoreErrors is false", () => {
  switch extractTable(~ignoreErrors=false, ~default=Some(JSON.Encode.bool(false))) {
  | Error(ExtractionError(_)) => passWith("cell extraction error propagated")
  | _ => failWith("Expected cell extraction error to propagate")
  }
})

test(
  "TableFieldExtractor uses the column default for cell errors when ignoreErrors is true",
  () => {
    switch extractTable(~ignoreErrors=true, ~default=Some(JSON.Encode.bool(false))) {
    | Ok(value) => isTextEqualTo("[{\"stock\":false}]", NodeUtil.jsonStringify(value))
    | Error(_) => failWith("Expected the column default to replace a failed cell")
    }
  },
)
