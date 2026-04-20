open Test
open Assertions
open ParseCli

let isMissingSelector = e =>
  switch e {
  | MissingSelector(_) => true
  | _ => false
  }

let isParseError = e =>
  switch e {
  | ParseError(_) => true
  | _ => false
  }

let isNoMatches = e =>
  switch e {
  | NoMatches(_) => true
  | _ => false
  }

let isValidOuterHtml = opts =>
  switch opts.extract {
  | OuterHtml => true
  | _ => false
  }

let isValidInnerHtml = opts =>
  switch opts.extract {
  | InnerHtml => true
  | _ => false
  }

let isValidText = opts =>
  switch opts.extract {
  | Text => true
  | _ => false
  }

let isValidAttr = (opts, name) =>
  switch opts.extract {
  | Attribute(n) => n == name
  | _ => false
  }

let isSingle = opts =>
  switch opts.mode {
  | Single => true
  | _ => false
  }

let isMultiple = opts =>
  switch opts.mode {
  | Multiple => true
  | _ => false
  }

let emptyValues: NodeJsBinding.Util.cliValues = {}

let withSelector = (values, sel): NodeJsBinding.Util.cliValues => {
  ...values,
  selector: sel,
}

let withExtract = (values, ex): NodeJsBinding.Util.cliValues => {
  ...values,
  extract: ex,
}

let withMode = (values, m): NodeJsBinding.Util.cliValues => {
  ...values,
  mode: m,
}

let withSchema = (values, s): NodeJsBinding.Util.cliValues => {
  ...values,
  schema: s,
}

let withSchemaPath = (values, p): NodeJsBinding.Util.cliValues => {
  ...values,
  schemaPath: p,
}

let withTable = (values, t): NodeJsBinding.Util.cliValues => {
  ...values,
  table: t,
}

let withOutput = (values, path): NodeJsBinding.Util.cliValues => {
  ...values,
  output: path,
}

let withFormat = (values, format): NodeJsBinding.Util.cliValues => {
  ...values,
  format,
}

test("runArgsValidation requires selector when no schema", () => {
  switch runArgsValidation(emptyValues) {
  | Error(e) => isTruthy(isMissingSelector(e))
  | Ok(_) => failWith("Expected MissingSelector error")
  }
})

test("runArgsValidation accepts empty selector string as missing", () => {
  let values = withSelector(emptyValues, "")
  switch runArgsValidation(values) {
  | Error(e) => isTruthy(isMissingSelector(e))
  | Ok(_) => failWith("Expected MissingSelector error for empty string")
  }
})

test("runArgsValidation accepts valid selector", () => {
  let values = withSelector(emptyValues, ".item")
  switch runArgsValidation(values) {
  | Ok(opts) => {
      isTextEqualTo(".item", opts.selector)
      isTruthy(isSingle(opts))
      isTruthy(isValidOuterHtml(opts))
    }
  | Error(_) => failWith("Expected successful validation")
  }
})

test("runArgsValidation defaults extract to outerHtml", () => {
  let values = withSelector(emptyValues, ".item")
  switch runArgsValidation(values) {
  | Ok(opts) => isTruthy(isValidOuterHtml(opts))
  | Error(_) => failWith("Expected outerHtml default")
  }
})

test("runArgsValidation parses innerHtml extract", () => {
  let values = withSelector(emptyValues, ".item")->withExtract("innerHtml")
  switch runArgsValidation(values) {
  | Ok(opts) => isTruthy(isValidInnerHtml(opts))
  | Error(_) => failWith("Expected innerHtml parse success")
  }
})

test("runArgsValidation parses text extract", () => {
  let values = withSelector(emptyValues, ".item")->withExtract("text")
  switch runArgsValidation(values) {
  | Ok(opts) => isTruthy(isValidText(opts))
  | Error(_) => failWith("Expected text parse success")
  }
})

test("runArgsValidation parses attr:name extract", () => {
  let values = withSelector(emptyValues, ".link")->withExtract("attr:href")
  switch runArgsValidation(values) {
  | Ok(opts) => isTruthy(isValidAttr(opts, "href"))
  | Error(_) => failWith("Expected attr:href parse success")
  }
})

test("runArgsValidation rejects empty attr extract", () => {
  let values = withSelector(emptyValues, ".link")->withExtract("attr:")
  switch runArgsValidation(values) {
  | Error(e) => isTruthy(isParseError(e))
  | Ok(_) => failWith("Expected ParseError for empty attr")
  }
})

test("runArgsValidation rejects unknown extract mode", () => {
  let values = withSelector(emptyValues, ".item")->withExtract("unknownMode")
  switch runArgsValidation(values) {
  | Error(e) => isTruthy(isParseError(e))
  | Ok(_) => failWith("Expected ParseError for unknown extract mode")
  }
})

test("runArgsValidation mode false means single result", () => {
  let values = withSelector(emptyValues, ".item")->withMode(false)
  switch runArgsValidation(values) {
  | Ok(opts) => isTruthy(isSingle(opts))
  | Error(_) => failWith("Expected single mode")
  }
})

test("runArgsValidation mode true means multiple results", () => {
  let values = withSelector(emptyValues, ".item")->withMode(true)
  switch runArgsValidation(values) {
  | Ok(opts) => isTruthy(isMultiple(opts))
  | Error(_) => failWith("Expected multiple mode")
  }
})

test("runArgsValidation --table takes precedence over schema and selector", () => {
  let values = emptyValues->withTable(true)->withSelector(".my-table")
  switch runArgsValidation(values) {
  | Ok(opts) =>
    switch opts.schemaSource {
    | Some(TableSelector(sel)) => isTextEqualTo(".my-table", sel)
    | _ => failWith("Expected TableSelector schema source")
    }
  | Error(_) => failWith("Expected table selector precedence")
  }
})

test("runArgsValidation --table uses selector as table selector", () => {
  let values = emptyValues->withTable(true)->withSelector(".custom-table")
  switch runArgsValidation(values) {
  | Ok(opts) =>
    switch opts.schemaSource {
    | Some(TableSelector(sel)) => isTextEqualTo(".custom-table", sel)
    | _ => failWith("Expected TableSelector schema source")
    }
  | Error(_) => failWith("Expected table selector")
  }
})

test("runArgsValidation --table defaults selector to table when omitted", () => {
  let values = emptyValues->withTable(true)
  switch runArgsValidation(values) {
  | Ok(opts) =>
    switch opts.schemaSource {
    | Some(TableSelector(sel)) => isTextEqualTo("table", sel)
    | _ => failWith("Expected TableSelector with default table")
    }
  | Error(_) => failWith("Expected table selector")
  }
})

test("runArgsValidation --schema takes precedence over --schemaPath", () => {
  let values = emptyValues->withSchema("{}")->withSchemaPath("/path/to/schema.json")
  switch runArgsValidation(values) {
  | Ok(opts) =>
    switch opts.schemaSource {
    | Some(InlineJson(_)) => pass()
    | _ => failWith("Expected InlineJson precedence")
    }
  | Error(_) => failWith("Expected InlineJson precedence")
  }
})

test("runArgsValidation --schemaPath creates FilePath source", () => {
  let values = emptyValues->withSchemaPath("/path/to/schema.json")
  switch runArgsValidation(values) {
  | Ok(opts) =>
    switch opts.schemaSource {
    | Some(FilePath(p)) => isTextEqualTo("/path/to/schema.json", p)
    | _ => failWith("Expected FilePath schema source")
    }
  | Error(_) => failWith("Expected FilePath")
  }
})

test("runArgsValidation schema makes selector optional", () => {
  let values = emptyValues->withSchema("{\"fields\":{}}")
  switch runArgsValidation(values) {
  | Ok(opts) => isTextEqualTo("", opts.selector)
  | Error(_) => failWith("Expected schema to make selector optional")
  }
})

test("runArgsValidation --table handles empty selector as table", () => {
  let values = emptyValues->withTable(true)->withSelector("")
  switch runArgsValidation(values) {
  | Ok(opts) =>
    switch opts.schemaSource {
    | Some(TableSelector(sel)) => isTextEqualTo("table", sel)
    | _ => failWith("Expected TableSelector")
    }
  | Error(_) => failWith("Expected empty selector defaulting to table")
  }
})

test("runArgsValidation accepts output path and defaults format to json", () => {
  let values = emptyValues->withSelector(".item")->withOutput("./result.json")
  switch runArgsValidation(values) {
  | Ok(opts) => {
      isOptionEqualTo(Some("./result.json"), opts.output, ~eq=(a, b) => a == b)
      switch opts.outputFormat {
      | Json => pass()
      | Ndjson => failWith("Expected json output format by default")
      }
    }
  | Error(_) => failWith("Expected output path to be accepted")
  }
})

test("runArgsValidation accepts ndjson format when output is provided", () => {
  let values =
    emptyValues->withSelector(".item")->withOutput("./result.ndjson")->withFormat("ndjson")
  switch runArgsValidation(values) {
  | Ok(opts) =>
    switch opts.outputFormat {
    | Ndjson => pass()
    | Json => failWith("Expected ndjson output format")
    }
  | Error(_) => failWith("Expected ndjson format to be accepted with output")
  }
})

test("runArgsValidation rejects invalid format when output is provided", () => {
  let values =
    emptyValues->withSelector(".item")->withOutput("./result.out")->withFormat("xml")
  switch runArgsValidation(values) {
  | Error(e) => isTruthy(isParseError(e))
  | Ok(_) => failWith("Expected ParseError for invalid --format")
  }
})

test("runArgsValidation ignores format when output is not provided", () => {
  let values = emptyValues->withSelector(".item")->withFormat("ndjson")
  switch runArgsValidation(values) {
  | Ok(opts) =>
    switch opts.outputFormat {
    | Json => pass()
    | Ndjson => failWith("Expected format to be ignored without output")
    }
  | Error(_) => failWith("Expected format without output to be ignored")
  }
})
