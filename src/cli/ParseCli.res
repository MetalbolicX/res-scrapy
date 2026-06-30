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

/* ============================================================================
   Phase 3 PR 2b: Flat Validation Pipeline
   Each validation step is a small function returning `result`. The main
   pipeline composes them with ResultX.flatMap instead of deeply nested
   switches. Every existing error/warning string is preserved verbatim.
   ============================================================================ */

let validateUserAgent: option<string> => result<option<string>, parseError> = ua => {
  switch ua {
  | Some(s) if s == "" =>
    Error(ParseError({message: "Invalid --user-agent value \"\". Expected a non-empty string.", details: None}))
  | Some(s) => Ok(Some(s))
  | None => Ok(None)
  }
}

let validateUrl: option<string> => result<option<string>, parseError> = url => {
  switch url {
  | Some(s) if s != "" => Ok(Some(s))
  | _ => Ok(None)
  }
}

let validateConcurrency: option<string> => result<int, parseError> = input => {
  switch input {
  | Some(s) =>
    switch Int.fromString(s) {
    | Some(n) if n >= 1 && n <= 20 => Ok(n)
    | Some(n) => Error(InvalidConcurrency(`Concurrency must be between 1 and 20, got ${Int.toString(n)}`))
    | None => Error(InvalidConcurrency(`Invalid concurrency value "${s}". Expected a number between 1 and 20`))
    }
  | None => Ok(5)
  }
}

let validateTimeout: option<string> => result<int, parseError> = input => {
  switch input {
  | Some(s) =>
    switch Int.fromString(s) {
    | Some(n) if n >= 1 => Ok(n)
    | Some(n) => Error(InvalidTimeout(`Timeout must be >= 1 second, got ${Int.toString(n)}`))
    | None => Error(InvalidTimeout(`Invalid timeout value "${s}". Expected a number of seconds (>= 1)`))
    }
  | None => Ok(30)
  }
}

let validateRetry: option<string> => result<int, parseError> = input => {
  switch input {
  | Some(s) =>
    switch Int.fromString(s) {
    | Some(n) if n >= 1 => Ok(n)
    | Some(n) => Error(InvalidRetry(`Retry count must be >= 1, got ${Int.toString(n)}`))
    | None => Error(InvalidRetry(`Invalid retry value "${s}". Expected a number (>= 1)`))
    }
  | None => Ok(3)
  }
}

let validateDelay: option<string> => result<int, parseError> = input => {
  switch input {
  | Some(s) =>
    switch Int.fromString(s) {
    | Some(n) if n >= 0 => Ok(n)
    | Some(n) => Error(InvalidDelay(`Delay must be >= 0 ms, got ${Int.toString(n)}`))
    | None => Error(InvalidDelay(`Invalid delay value "${s}". Expected milliseconds (>= 0)`))
    }
  | None => Ok(0)
  }
}

let validateTableSelector: (option<string>, bool) => option<schemaSource> = (selector, tableOpt) => {
  if tableOpt {
    let sel = selector->Option.getOr("table")
    Some(TableSelector(sel == "" ? "table" : sel))
  } else {
    None
  }
}

let validateSchemaSource: (option<string>, option<string>, option<schemaSource>) => result<
  option<schemaSource>,
  parseError,
> = (schemaOpt, schemaPathOpt, tableSource) => {
  switch tableSource {
  | Some(_) as t => Ok(t)
  | None =>
    switch (schemaOpt, schemaPathOpt) {
    | (Some(s), _) if s != "" => Ok(Some(InlineJson(s)))
    | (_, Some(p)) if p != "" => Ok(Some(FilePath(p)))
    | _ => Ok(None)
    }
  }
}

let validateOutputPath: option<string> => option<string> = outputOpt => {
  switch outputOpt {
  | Some(path) if path != "" => Some(path)
  | _ => None
  }
}

/* Pure decision: should the --format flag trigger a warning?
   Kept verbatim with the previous inline expression so the exact warning
   string is preserved. */
let formatWarning: (option<string>, option<string>) => array<string> = (outputOpt, formatOpt) => {
  switch (outputOpt, formatOpt) {
  | (None, Some(fmt)) if fmt != "json" => [
      "Warning: --format is ignored unless --output is provided; stdout always uses JSON array format.",
    ]
  | _ => []
  }
}

/* Pure: produce the list of fetch-related flag names that were set on the CLI. */
let fetchFlagNames: NodeJsBinding.Util.cliValues => array<string> = values => {
  let names: ref<array<string>> = ref([])
  switch values.userAgent {
  | Some(_) => names := names.contents->Array.concat(["--user-agent"])
  | None => ()
  }
  switch values.timeout {
  | Some(_) => names := names.contents->Array.concat(["--timeout"])
  | None => ()
  }
  switch values.retry {
  | Some(_) => names := names.contents->Array.concat(["--retry"])
  | None => ()
  }
  switch values.delay {
  | Some(_) => names := names.contents->Array.concat(["--delay"])
  | None => ()
  }
  switch values.header {
  | Some(_) => names := names.contents->Array.concat(["--header"])
  | None => ()
  }
  switch values.cookie {
  | Some(_) => names := names.contents->Array.concat(["--cookie"])
  | None => ()
  }
  names.contents
}

let fetchWarning: (option<string>, array<string>) => array<string> = (urlOpt, flags) => {
  switch (urlOpt, Array.length(flags)) {
  | (None, n) if n > 0 => [
      `Warning: ${Array.join(flags, ", ")} is ignored in stdin mode (no --url provided).`,
    ]
  | _ => []
  }
}

let validateOutputFormat: (option<string>, option<string>) => result<outputFormat, parseError> = (
  outputOpt,
  formatOpt,
) => {
  switch outputOpt {
  | None => Ok(Json)
  | Some(_) =>
    switch formatOpt {
    | Some("json") | None => Ok(Json)
    | Some("ndjson") => Ok(Ndjson)
    | Some(s) =>
      Error(ParseError({message: `Invalid --format value "${s}". Valid values are: json, ndjson`, details: None}))
    }
  }
}

let validateSelector: (option<string>, option<string>, option<schemaSource>) => result<string, parseError> = (
  urlOpt,
  selectorOpt,
  schemaSrc,
) => {
  switch (urlOpt, schemaSrc) {
  | (Some(_), Some(_)) => Ok(selectorOpt->Option.getOr(""))
  | (Some(_), None) =>
    switch selectorOpt {
    | None | Some("") =>
      Error(InvalidUrlMode("When using --url, an extraction flag is required (--selector/-s, --schemaPath/-p, or --table/-t)"))
    | Some(s) => Ok(s)
    }
  | (None, Some(_)) => Ok(selectorOpt->Option.getOr(""))
  | (None, None) =>
    switch selectorOpt {
    | None | Some("") => Error(MissingSelector("Selector is required (--selector/-s)"))
    | Some(s) => Ok(s)
    }
  }
}

let validateExtract: option<string> => result<extractMode, parseError> = extractOpt => {
  switch extractOpt->Option.getOr("outerHtml") {
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
}

/* Convenience record bundling all the validated scalars so the final
   pipeline block can build the parseOptions without repattern-matching. */
type validatedScalars = {
  userAgent: option<string>,
  url: option<string>,
  concurrency: int,
  timeoutSeconds: int,
  retryCount: int,
  delayMs: int,
}

let validateScalars: NodeJsBinding.Util.cliValues => result<validatedScalars, parseError> = values => {
  validateUserAgent(values.userAgent)
  ->ResultX.flatMap(userAgent =>
    validateUrl(values.url)
    ->ResultX.flatMap(url =>
      validateConcurrency(values.concurrency)
      ->ResultX.flatMap(concurrency =>
        validateTimeout(values.timeout)
        ->ResultX.flatMap(timeoutSeconds =>
          validateRetry(values.retry)
          ->ResultX.flatMap(retryCount =>
            validateDelay(values.delay)
            ->Result.map(delayMs => {
              userAgent,
              url,
              concurrency,
              timeoutSeconds,
              retryCount,
              delayMs,
            })
          )
        )
      )
    )
  )
}

/* Composes request-headers validation with warning computation that depends
   on the parsed headers. */
let validateHeadersAndWarnings: (
  NodeJsBinding.Util.cliValues,
  option<string>,
  array<string>,
) => result<(array<headerEntry>, array<string>), parseError> = (
  values,
  urlOpt,
  fetchFlags,
) => {
  parseRequestHeaders(values.header, values.cookie)
  ->Result.map(requestHeaders => {
    let formatWarnings = formatWarning(values.output, values.format)
    let fetchWarnings = fetchWarning(urlOpt, fetchFlags)
    (requestHeaders, formatWarnings->Array.concat(fetchWarnings))
  })
}

/**
  * Validates the command line arguments and returns either a parseOptions object or a parseError
  * Checks that the selector is provided and not empty
  * Checks that the mode is valid if provided, defaulting to "single"
  *
  * Flat-pipeline implementation: each validation step is a small function
  * returning `result`; this entry-point composes them with ResultX.flatMap
  * instead of nested switches.
  */
let runArgsValidation: NodeJsBinding.Util.cliValues => result<parseOptions, parseError> = values => {
  let fetchFlags = fetchFlagNames(values)

  validateScalars(values)
  ->ResultX.flatMap(scalars => {
    let {userAgent, url, concurrency, timeoutSeconds, retryCount, delayMs} = scalars

    let tableSource = validateTableSelector(values.selector, values.table->Option.getOr(false))

    validateSchemaSource(values.schema, values.schemaPath, tableSource)
    ->ResultX.flatMap(schemaSource =>
      validateHeadersAndWarnings(values, url, fetchFlags)
      ->ResultX.flatMap(((requestHeaders, warnings)) => {
        let output = validateOutputPath(values.output)

        validateOutputFormat(output, values.format)
        ->ResultX.flatMap(outputFormat =>
          validateSelector(url, values.selector, schemaSource)
          ->ResultX.flatMap(selector =>
            validateExtract(values.extract)
            ->Result.map(extract => {
              let modeFromBoolValue = values.mode->Option.getOr(false)
              let mode = modeFromBool(modeFromBoolValue)
              {
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
              }
            })
          )
        )
      })
    )
  })
}
