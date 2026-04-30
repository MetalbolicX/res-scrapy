open Test
open Assertions
open TestHelpers
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

let withUserAgent = (values, ua): NodeJsBinding.Util.cliValues => {
  ...values,
  userAgent: ua,
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

test("runArgsValidation rejects empty --user-agent", () => {
  let values = emptyValues->withSelector(".item")->withUserAgent("")
  switch runArgsValidation(values) {
  | Error(e) => isTruthy(isParseError(e))
  | Ok(_) => failWith("Expected ParseError for empty --user-agent")
  }
})

test("runArgsValidation accepts non-empty --user-agent", () => {
  let values = emptyValues->withSelector(".item")->withUserAgent("MyBot/1.0")
  switch runArgsValidation(values) {
  | Ok(opts) => isOptionEqualTo(Some("MyBot/1.0"), opts.userAgent, ~eq=(a, b) => a == b)
  | Error(_) => failWith("Expected non-empty --user-agent to be accepted")
  }
})

test("runArgsValidation warns that --user-agent is ignored without --url", () => {
  let values = emptyValues->withSelector(".item")->withUserAgent("MyBot/1.0")
  switch runArgsValidation(values) {
  | Ok(opts) => {
      isIntEqualTo(1, opts.warnings->Array.length)
      let warning = opts.warnings->Array.get(0)->Option.getOr("")
      stringContains(warning, "--user-agent")->isTruthy
      stringContains(warning, "stdin mode")->isTruthy
    }
  | Error(_) => failWith("Expected warning for --user-agent without --url")
  }
})

test("runArgsValidation does not warn for --user-agent in URL mode", () => {
  let values = {
    ...emptyValues,
    selector: ".item",
    userAgent: "MyBot/1.0",
    url: "https://example.com/page-{1..2}.html",
  }
  switch runArgsValidation(values) {
  | Ok(opts) => {
      let hasUserAgentIgnoredWarning =
        opts.warnings
        ->Array.some(w =>
          stringContains(w, "--user-agent") && stringContains(w, "ignored in stdin mode")
        )
      isTruthy(hasUserAgentIgnoredWarning == false)
      isIntEqualTo(30, opts.timeoutSeconds)
      isIntEqualTo(3, opts.retryCount)
      isIntEqualTo(0, opts.delayMs)
    }
  | Error(_) => failWith("Expected URL mode to accept --user-agent without stdin warning")
  }
})

test("runArgsValidation parses valid --timeout seconds", () => {
  let values = {
    ...emptyValues,
    selector: ".item",
    timeout: "45",
  }
  switch runArgsValidation(values) {
  | Ok(opts) => isIntEqualTo(45, opts.timeoutSeconds)
  | Error(_) => failWith("Expected valid --timeout to parse")
  }
})

test("runArgsValidation rejects invalid non-numeric --timeout", () => {
  let values = {
    ...emptyValues,
    selector: ".item",
    timeout: "abc",
  }
  switch runArgsValidation(values) {
  | Error(e) =>
    switch e {
    | InvalidTimeout(msg) => stringContains(msg, "Invalid timeout value")->isTruthy
    | _ => failWith("Expected InvalidTimeout for non-numeric value")
    }
  | Ok(_) => failWith("Expected InvalidTimeout for non-numeric --timeout")
  }
})

test("runArgsValidation rejects timeout less than 1", () => {
  let values = {
    ...emptyValues,
    selector: ".item",
    timeout: "0",
  }
  switch runArgsValidation(values) {
  | Error(e) =>
    switch e {
    | InvalidTimeout(msg) => stringContains(msg, "must be >= 1")->isTruthy
    | _ => failWith("Expected InvalidTimeout for timeout < 1")
    }
  | Ok(_) => failWith("Expected InvalidTimeout for timeout < 1")
  }
})

test("runArgsValidation warns that --timeout is ignored without --url", () => {
  let values = {
    ...emptyValues,
    selector: ".item",
    timeout: "40",
  }
  switch runArgsValidation(values) {
  | Ok(opts) => {
      let hasTimeoutWarning =
        opts.warnings->Array.some(w =>
          stringContains(w, "--timeout") && stringContains(w, "ignored in stdin mode")
        )
      isTruthy(hasTimeoutWarning)
    }
  | Error(_) => failWith("Expected warning for --timeout without --url")
  }
})

test("runArgsValidation parses valid --retry", () => {
  let values = {
    ...emptyValues,
    selector: ".item",
    retry: "5",
  }
  switch runArgsValidation(values) {
  | Ok(opts) => isIntEqualTo(5, opts.retryCount)
  | Error(_) => failWith("Expected valid --retry to parse")
  }
})

test("runArgsValidation parses repeatable --header and --cookie", () => {
  let values = {
    ...emptyValues,
    selector: ".item",
    header: ["Accept: text/html", "X-Trace: abc"],
    cookie: ["session=one", "lang=en"],
  }
  switch runArgsValidation(values) {
  | Ok(opts) => {
      isIntEqualTo(3, opts.requestHeaders->Array.length)
      let hasAccept = opts.requestHeaders->Array.some(h => h.name == "accept" && h.value == "text/html")
      let hasTrace = opts.requestHeaders->Array.some(h => h.name == "x-trace" && h.value == "abc")
      let hasCookie = opts.requestHeaders->Array.some(h => h.name == "cookie" && h.value == "session=one; lang=en")
      isTruthy(hasAccept)
      isTruthy(hasTrace)
      isTruthy(hasCookie)
    }
  | Error(_) => failWith("Expected headers and cookies to parse")
  }
})

test("runArgsValidation rejects malformed --header", () => {
  let values = {
    ...emptyValues,
    selector: ".item",
    header: ["MissingColon"],
  }
  switch runArgsValidation(values) {
  | Error(e) =>
    switch e {
    | InvalidHeader(msg) => stringContains(msg, "Expected format")->isTruthy
    | _ => failWith("Expected InvalidHeader for malformed --header")
    }
  | Ok(_) => failWith("Expected InvalidHeader for malformed --header")
  }
})

test("runArgsValidation merges duplicate header names with last value wins", () => {
  let values = {
    ...emptyValues,
    selector: ".item",
    header: ["Accept: application/json", "accept: text/html"],
  }
  switch runArgsValidation(values) {
  | Ok(opts) => {
      let accepts = opts.requestHeaders->Array.filter(h => h.name == "accept")
      isIntEqualTo(1, accepts->Array.length)
      let firstValue = switch accepts->Array.get(0) {
      | Some(h) => h.value
      | None => ""
      }
      isTextEqualTo("text/html", firstValue)
    }
  | Error(_) => failWith("Expected duplicate header normalization")
  }
})

test("runArgsValidation warns that --header and --cookie are ignored without --url", () => {
  let values = {
    ...emptyValues,
    selector: ".item",
    header: ["Accept: text/html"],
    cookie: ["session=one"],
  }
  switch runArgsValidation(values) {
  | Ok(opts) => {
      let hasHeadersWarning =
        opts.warnings->Array.some(w =>
          stringContains(w, "--header") && stringContains(w, "--cookie") && stringContains(w, "ignored in stdin mode")
        )
      isTruthy(hasHeadersWarning)
    }
  | Error(_) => failWith("Expected ignored warning for --header/--cookie without --url")
  }
})

test("runArgsValidation rejects non-numeric --retry", () => {
  let values = {
    ...emptyValues,
    selector: ".item",
    retry: "abc",
  }
  switch runArgsValidation(values) {
  | Error(e) =>
    switch e {
    | InvalidRetry(msg) => stringContains(msg, "Invalid retry value")->isTruthy
    | _ => failWith("Expected InvalidRetry for non-numeric --retry")
    }
  | Ok(_) => failWith("Expected InvalidRetry for non-numeric --retry")
  }
})

test("runArgsValidation rejects retry less than 1", () => {
  let values = {
    ...emptyValues,
    selector: ".item",
    retry: "0",
  }
  switch runArgsValidation(values) {
  | Error(e) =>
    switch e {
    | InvalidRetry(msg) => stringContains(msg, "must be >= 1")->isTruthy
    | _ => failWith("Expected InvalidRetry for retry < 1")
    }
  | Ok(_) => failWith("Expected InvalidRetry for retry < 1")
  }
})

test("runArgsValidation warns that --retry is ignored without --url", () => {
  let values = {
    ...emptyValues,
    selector: ".item",
    retry: "4",
  }
  switch runArgsValidation(values) {
  | Ok(opts) => {
      let hasRetryWarning =
        opts.warnings->Array.some(w =>
          stringContains(w, "--retry") && stringContains(w, "ignored in stdin mode")
        )
      isTruthy(hasRetryWarning)
    }
  | Error(_) => failWith("Expected warning for --retry without --url")
  }
})

test("runArgsValidation parses valid --delay milliseconds", () => {
  let values = {
    ...emptyValues,
    selector: ".item",
    delay: "250",
  }
  switch runArgsValidation(values) {
  | Ok(opts) => isIntEqualTo(250, opts.delayMs)
  | Error(_) => failWith("Expected valid --delay to parse")
  }
})

test("runArgsValidation rejects negative --delay", () => {
  let values = {
    ...emptyValues,
    selector: ".item",
    delay: "-5",
  }
  switch runArgsValidation(values) {
  | Error(e) =>
    switch e {
    | InvalidDelay(msg) => stringContains(msg, "Delay must be >= 0")->isTruthy
    | _ => failWith("Expected InvalidDelay for negative --delay")
    }
  | Ok(_) => failWith("Expected InvalidDelay for negative --delay")
  }
})

test("runArgsValidation rejects non-numeric --delay", () => {
  let values = {
    ...emptyValues,
    selector: ".item",
    delay: "abc",
  }
  switch runArgsValidation(values) {
  | Error(e) =>
    switch e {
    | InvalidDelay(msg) => stringContains(msg, "Invalid delay value")->isTruthy
    | _ => failWith("Expected InvalidDelay for non-numeric --delay")
    }
  | Ok(_) => failWith("Expected InvalidDelay for non-numeric --delay")
  }
})

test("runArgsValidation warns that --delay is ignored without --url", () => {
  let values = {
    ...emptyValues,
    selector: ".item",
    delay: "100",
  }
  switch runArgsValidation(values) {
  | Ok(opts) => {
      let hasDelayWarning =
        opts.warnings->Array.some(w =>
          stringContains(w, "--delay") && stringContains(w, "ignored in stdin mode")
        )
      isTruthy(hasDelayWarning)
    }
  | Error(_) => failWith("Expected warning for --delay without --url")
  }
})
