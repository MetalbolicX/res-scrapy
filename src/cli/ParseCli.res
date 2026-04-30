type mode = Single | Multiple

type extractMode =
  | OuterHtml
  | InnerHtml
  | Text
  | Attribute(string)

/** Describes how to supply a schema for structured extraction. */
type schemaSource =
  /** Inline JSON string passed via `--schema/-c`. */
  | InlineJson(string)
  /** Path to a `.json` file passed via `--schemaPath/-p`. */
  | FilePath(string)
  /** CSS selector pointing to a `<table>` element.
    * Set via `--table/-t` (boolean); the selector value comes from `--selector/-s`,
    * defaulting to `"table"` when `--selector` is absent. */
  | TableSelector(string)

type outputFormat = Json | Ndjson

type headerEntry = {
  name: string,
  value: string,
}

/**
  * Validated, fully-typed options produced by `runArgsValidation`.
  *
  * - `selector`     — CSS selector; always non-empty.
  * - `extractText`  — when `true`, use `.textContent`; otherwise `.outerHTML`.
  * - `mode`         — `Single` (first match) or `Multiple` (all matches).
  * - `schemaSource` — optional structured-extraction descriptor; takes precedence
  *                    over `selector`/`mode`/`extractText` when present.
  *                    `TableSelector` triggers table extraction.
  * - `url`          — optional URL or URL template for multi-page fetching.
  * - `concurrency`  — max concurrent fetches (1-20).
  */
type parseOptions = {
  selector: string,
  extract: extractMode,
  mode: mode,
  schemaSource?: schemaSource,
  output?: string,
  outputFormat: outputFormat,
  warnings: array<string>,
  url?: string,
  concurrency: int,
  userAgent?: string,
  timeoutSeconds: int,
  retryCount: int,
  delayMs: int,
  requestHeaders: array<headerEntry>,
}

/** Errors produced during argument validation. */
type parseError =
  | MissingSelector(string)
  | ParseError({message: string, details: option<JsExn.t>})
  | NoMatches({message: string, selector: string})
  | InvalidConcurrency(string)
  | InvalidTimeout(string)
  | InvalidRetry(string)
  | InvalidDelay(string)
  | InvalidHeader(string)
  | InvalidUrlMode(string)

/**
  * Converts a boolean to a mode type.
  * true -> Multiple results, false -> Single result
 */
let modeFromBool: bool => mode = isMultiple => isMultiple ? Multiple : Single

let normalizeHeaderName = (name: string): string =>
  name->String.toLowerCase

let trimHeaderPart = (value: string): string =>
  value->String.trim

let parseHeaderLine: string => result<headerEntry, parseError> = raw => {
  let line = raw->trimHeaderPart
  if line == "" {
    Error(InvalidHeader("Invalid --header value \"\". Expected format: Name: Value"))
  } else {
    let idx = line->String.indexOf(":")
    if idx <= 0 {
      Error(InvalidHeader(`Invalid --header value "${raw}". Expected format: Name: Value`))
    } else {
      let name = line->String.slice(~start=0, ~end=idx)->trimHeaderPart
      let value = line->String.slice(~start=idx + 1, ~end=String.length(line))->trimHeaderPart
      if name == "" || value == "" {
        Error(InvalidHeader(`Invalid --header value "${raw}". Header name and value must be non-empty`))
      } else {
        Ok({name: normalizeHeaderName(name), value})
      }
    }
  }
}

let upsertHeader = (acc: array<headerEntry>, entry: headerEntry): array<headerEntry> => {
  let idx = acc->Array.findIndex(h => h.name == entry.name)
  switch idx {
  | -1 => Array.concat(acc, [entry])
  | _ => {
      let withoutExisting = acc->Array.filter(h => h.name != entry.name)
      Array.concat(withoutExisting, [entry])
    }
  }
}

let parseRequestHeaders = (
  headersOpt: option<array<string>>,
  cookiesOpt: option<array<string>>,
): result<array<headerEntry>, parseError> => {
  let headerInputs = headersOpt->Option.getOr([])
  let cookieInputs = cookiesOpt->Option.getOr([])

  let baseResultRef: ref<result<array<headerEntry>, parseError>> = ref(Ok([]))
  headerInputs->Array.forEach(raw =>
    switch baseResultRef.contents {
    | Error(_) => ()
    | Ok(acc) =>
      switch parseHeaderLine(raw) {
      | Error(e) => baseResultRef := Error(e)
      | Ok(entry) => baseResultRef := Ok(upsertHeader(acc, entry))
      }
    }
  )
  let baseResult = baseResultRef.contents

  switch baseResult {
  | Error(_) as e => e
  | Ok(acc) => {
      let cookieValue = cookieInputs
      ->Array.map(trimHeaderPart)
      ->Array.filter(v => v != "")
      ->Array.join("; ")
      if cookieValue == "" {
        Ok(acc)
      } else {
        Ok(upsertHeader(acc, {name: "cookie", value: cookieValue}))
      }
    }
  }
}

/**
  * Validates the command line arguments and returns either a parseOptions object or a parseError
  * Checks that the selector is provided and not empty
  * Checks that the mode is valid if provided, defaulting to "single"
 */
let runArgsValidation: NodeJsBinding.Util.cliValues => result<parseOptions, parseError> = values => {
  switch parseRequestHeaders(values.header, values.cookie) {
  | Error(e) => Error(e)
  | Ok(requestHeaders) =>
    switch values.userAgent {
    | Some(ua) if ua == "" =>
      Error(ParseError({message: "Invalid --user-agent value \"\". Expected a non-empty string.", details: None}))
    | _ => {
        let userAgent = switch values.userAgent {
        | Some(ua) if ua != "" => Some(ua)
        | _ => None
        }
        let url = switch values.url {
        | Some(u) if u != "" => Some(u)
        | _ => None
        }

        let concurrencyResult: result<int, parseError> = switch values.concurrency {
        | Some(s) =>
          switch Int.fromString(s) {
          | Some(n) if n >= 1 && n <= 20 => Ok(n)
          | Some(n) => Error(InvalidConcurrency(`Concurrency must be between 1 and 20, got ${Int.toString(n)}`))
          | None => Error(InvalidConcurrency(`Invalid concurrency value "${s}". Expected a number between 1 and 20`))
          }
        | None => Ok(5)
        }

        switch concurrencyResult {
        | Error(e) => Error(e)
        | Ok(concurrency) => {
            let timeoutResult: result<int, parseError> = switch values.timeout {
            | Some(s) =>
              switch Int.fromString(s) {
              | Some(n) if n >= 1 => Ok(n)
              | Some(n) => Error(InvalidTimeout(`Timeout must be >= 1 second, got ${Int.toString(n)}`))
              | None => Error(InvalidTimeout(`Invalid timeout value "${s}". Expected a number of seconds (>= 1)`))
              }
            | None => Ok(30)
            }
            switch timeoutResult {
            | Error(e) => Error(e)
            | Ok(timeoutSeconds) => {
                let retryResult: result<int, parseError> = switch values.retry {
                | Some(s) =>
                  switch Int.fromString(s) {
                  | Some(n) if n >= 1 => Ok(n)
                  | Some(n) => Error(InvalidRetry(`Retry count must be >= 1, got ${Int.toString(n)}`))
                  | None => Error(InvalidRetry(`Invalid retry value "${s}". Expected a number (>= 1)`))
                  }
                | None => Ok(3)
                }
                switch retryResult {
                | Error(e) => Error(e)
                | Ok(retryCount) => {
                    let delayResult: result<int, parseError> = switch values.delay {
                    | Some(s) =>
                      switch Int.fromString(s) {
                      | Some(n) if n >= 0 => Ok(n)
                      | Some(n) => Error(InvalidDelay(`Delay must be >= 0 ms, got ${Int.toString(n)}`))
                      | None => Error(InvalidDelay(`Invalid delay value "${s}". Expected milliseconds (>= 0)`))
                      }
                    | None => Ok(0)
                    }
                    switch delayResult {
                    | Error(e) => Error(e)
                    | Ok(delayMs) => {
                        let tableSource: option<schemaSource> = switch values.table {
                        | Some(true) => {
                            let sel = values.selector->Option.getOr("table")
                            Some(TableSelector(sel == "" ? "table" : sel))
                          }
                        | _ => None
                        }
                        let schemaSource: option<schemaSource> = switch tableSource {
                        | Some(_) as t => t
                        | None =>
                          switch (values.schema, values.schemaPath) {
                          | (Some(s), _) if s != "" => Some(InlineJson(s))
                          | (_, Some(p)) if p != "" => Some(FilePath(p))
                          | _ => None
                          }
                        }
                        let output = switch values.output {
                        | Some(path) if path != "" => Some(path)
                        | _ => None
                        }
                        let warnings = {
                          let formatWarnings = switch (output, values.format) {
                          | (None, Some(fmt)) if fmt != "json" =>
                            ["Warning: --format is ignored unless --output is provided; stdout always uses JSON array format."]
                          | _ => []
                          }
                          let fetchFlagNames = {
                            let names: array<string> = []
                            switch userAgent { | Some(_) => names->Array.push("--user-agent") | None => () }
                            switch values.timeout { | Some(_) => names->Array.push("--timeout") | None => () }
                            switch values.retry { | Some(_) => names->Array.push("--retry") | None => () }
                            switch values.delay { | Some(_) => names->Array.push("--delay") | None => () }
                            switch values.header { | Some(_) => names->Array.push("--header") | None => () }
                            switch values.cookie { | Some(_) => names->Array.push("--cookie") | None => () }
                            names
                          }
                          let fetchWarnings = switch (url, fetchFlagNames->Array.length) {
                          | (None, n) if n > 0 => [
                              `Warning: ${fetchFlagNames->Array.join(", ")} is ignored in stdin mode (no --url provided).`,
                            ]
                          | _ => []
                          }
                          Array.concat(formatWarnings, fetchWarnings)
                        }
                        let outputFormatResult: result<outputFormat, parseError> = switch output {
                        | None => Ok(Json)
                        | Some(_) =>
                          switch values.format {
                          | Some("json") | None => Ok(Json)
                          | Some("ndjson") => Ok(Ndjson)
                          | Some(s) =>
                            Error(ParseError({message: `Invalid --format value "${s}". Valid values are: json, ndjson`, details: None}))
                          }
                        }
                        let selectorResult: result<string, parseError> = switch (url, schemaSource) {
                        | (Some(_), Some(_)) => Ok(values.selector->Option.getOr(""))
                        | (Some(_), None) =>
                          switch values.selector {
                          | None | Some("") =>
                            Error(InvalidUrlMode("When using --url, an extraction flag is required (--selector/-s, --schemaPath/-p, or --table/-t)"))
                          | Some(s) => Ok(s)
                          }
                        | (None, Some(_)) => Ok(values.selector->Option.getOr(""))
                        | (None, None) =>
                          switch values.selector {
                          | None | Some("") => Error(MissingSelector("Selector is required (--selector/-s)"))
                          | Some(s) => Ok(s)
                          }
                        }
                        switch selectorResult {
                        | Error(e) => Error(e)
                        | Ok(selector) => {
                            let extractResult: result<extractMode, parseError> = switch values.extract->Option.getOr("outerHtml") {
                            | "outerHtml" => Ok(OuterHtml)
                            | "innerHtml" => Ok(InnerHtml)
                            | "text" => Ok(Text)
                            | s if String.startsWith(s, "attr:") => {
                                let attr = String.slice(s, ~start=5, ~end=String.length(s))
                                if attr == "" {
                                  Error(ParseError({message: "Invalid --extract value \"attr:\". Expected format: attr:<name>", details: None}))
                                } else {
                                  Ok(Attribute(attr))
                                }
                              }
                            | s =>
                              Error(ParseError({message: `Invalid --extract value "${s}". Valid values are: outerHtml, innerHtml, text, attr:<name>`, details: None}))
                            }
                            switch extractResult {
                            | Error(e) => Error(e)
                            | Ok(extract) =>
                              switch outputFormatResult {
                              | Error(e) => Error(e)
                              | Ok(outputFormat) => {
                                  let modeFromBoolValue = values.mode->Option.getOr(false)
                                  let mode = modeFromBool(modeFromBoolValue)
                                  Ok({
                                    selector,
                                    extract,
                                    mode,
                                    ?schemaSource,
                                    ?output,
                                    outputFormat,
                                    warnings,
                                    ?url,
                                    concurrency,
                                    ?userAgent,
                                    timeoutSeconds,
                                    retryCount,
                                    delayMs,
                                    requestHeaders,
                                  })
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
