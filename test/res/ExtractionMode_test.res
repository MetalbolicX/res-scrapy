open Test
open Assertions

test("ExtractionMode.fromOptions picks table mode", () => {
  let options: ParseCli.parseOptions = {
    selector: ".unused",
    extract: OuterHtml,
    mode: Single,
    schemaSource: TableSelector("table.users"),
  }

  switch ExtractionMode.fromOptions(options) {
  | TableMode(selector) => isTextEqualTo("table.users", selector)
  | _ => failWith("Expected TableMode")
  }
})

test("ExtractionMode.fromOptions picks schema mode", () => {
  let options: ParseCli.parseOptions = {
    selector: "",
    extract: OuterHtml,
    mode: Single,
    schemaSource: InlineJson("{}"),
  }

  switch ExtractionMode.fromOptions(options) {
  | SchemaMode(InlineJson(raw)) => isTextEqualTo("{}", raw)
  | _ => failWith("Expected SchemaMode")
  }
})

test("ExtractionMode.fromOptions picks selector mode", () => {
  let options: ParseCli.parseOptions = {
    selector: ".item",
    extract: Text,
    mode: Multiple,
  }

  switch ExtractionMode.fromOptions(options) {
  | SelectorMode({selector, extract, mode}) => {
      isTextEqualTo(".item", selector)
      switch extract {
      | Text => passWith("extract mode ok")
      | _ => failWith("Expected Text extract mode")
      }
      switch mode {
      | Multiple => passWith("mode ok")
      | _ => failWith("Expected Multiple mode")
      }
    }
  | _ => failWith("Expected SelectorMode")
  }
})
