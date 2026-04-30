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
}

/** Errors produced during argument validation. */
type parseError =
  | MissingSelector(string)
  | ParseError({message: string, details: option<JsExn.t>})
  | NoMatches({message: string, selector: string})
  | InvalidConcurrency(string)
  | InvalidUrlMode(string)

/**
  * Converts a boolean to a mode type.
  * true -> Multiple results, false -> Single result
 */
let modeFromBool: bool => mode = isMultiple => isMultiple ? Multiple : Single

/**
  * Validates the command line arguments and returns either a parseOptions object or a parseError
  * Checks that the selector is provided and not empty
  * Checks that the mode is valid if provided, defaulting to "single"
 */
let runArgsValidation: NodeJsBinding.Util.cliValues => result<
  parseOptions,
  parseError,
> = values => {
  // Parse URL option
  let url = switch values.url {
  | Some(u) if u != "" => Some(u)
  | _ => None
  }

  // Validate concurrency
  let concurrencyResult: result<int, parseError> = switch values.concurrency {
  | Some(s) =>
    switch Int.fromString(s) {
    | Some(n) if n >= 1 && n <= 20 => Ok(n)
    | Some(n) =>
      Error(
        InvalidConcurrency(
          `Concurrency must be between 1 and 20, got ${Int.toString(n)}`,
        ),
      )
    | None =>
      Error(
        InvalidConcurrency(
          `Invalid concurrency value "${s}". Expected a number between 1 and 20`,
        ),
      )
    }
  | None => Ok(5) // Default
  }

  switch concurrencyResult {
  | Error(e) => Error(e)
  | Ok(concurrency) => {
      // `--table/-t` takes precedence over schema and selector flags.
      // When set, use --selector as the table CSS selector (defaulting to "table").
      let tableSource: option<schemaSource> = switch values.table {
      | Some(true) => {
          let sel = values.selector->Option.getOr("table")
          Some(TableSelector(sel == "" ? "table" : sel))
        }
      | _ => None
      }

      // Resolve schema source — only consulted when --table is absent
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

      let warnings = switch (output, values.format) {
      | (None, Some(fmt)) if fmt != "json" =>
        [
          "Warning: --format is ignored unless --output is provided; stdout always uses JSON array format.",
        ]
      | _ => []
      }

      let outputFormatResult: result<outputFormat, parseError> = switch output {
      | None => Ok(Json)
      | Some(_) =>
        switch values.format {
        | Some("json") | None => Ok(Json)
        | Some("ndjson") => Ok(Ndjson)
        | Some(s) =>
          Error(
            ParseError({
              message: `Invalid --format value "${s}". Valid values are: json, ndjson`,
              details: None,
            }),
          )
        }
      }

      // When URL mode is used, --selector or schema is required
      let selectorResult: result<string, parseError> = switch (url, schemaSource) {
      | (Some(_), Some(_)) => Ok(values.selector->Option.getOr(""))
      | (Some(_), None) =>
        switch values.selector {
        | None | Some("") =>
          Error(
            InvalidUrlMode(
              "When using --url, an extraction flag is required (--selector/-s, --schemaPath/-p, or --table/-t)",
            ),
          )
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
          let extractResult: result<extractMode, parseError> = switch values.extract->Option.getOr(
            "outerHtml",
          ) {
          | "outerHtml" => Ok(OuterHtml)
          | "innerHtml" => Ok(InnerHtml)
          | "text" => Ok(Text)
          | s if String.startsWith(s, "attr:") => {
              let attr = String.slice(s, ~start=5, ~end=String.length(s))
              if attr == "" {
                Error(
                  ParseError({
                    message: "Invalid --extract value \"attr:\". Expected format: attr:<name>",
                    details: None,
                  }),
                )
              } else {
                Ok(Attribute(attr))
              }
            }
          | s =>
            Error(
              ParseError({
                message: `Invalid --extract value "${s}". Valid values are: outerHtml, innerHtml, text, attr:<name>`,
                details: None,
              }),
            )
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
                })
              }
            }
          }
        }
      }
    }
  }
}
