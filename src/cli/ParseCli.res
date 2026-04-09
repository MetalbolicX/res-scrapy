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

/**
  * Validated, fully-typed options produced by `runArgsValidation`.
  *
  * - `selector`     — CSS selector; always non-empty.
  * - `extractText`  — when `true`, use `.textContent`; otherwise `.outerHTML`.
  * - `mode`         — `Single` (first match) or `Multiple` (all matches).
  * - `schemaSource` — optional structured-extraction descriptor; takes precedence
  *                    over `selector`/`mode`/`extractText` when present.
  *                    `TableSelector` triggers table extraction.
 */
type parseOptions = {
  selector: string,
  extract: extractMode,
  mode: mode,
  schemaSource?: schemaSource,
}

/** Errors produced during argument validation. */
type parseError =
  | MissingSelector(string)
  | ParseError({message: string, details: option<JsExn.t>})
  | NoMatches({message: string, selector: string})

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

  // When a schema is provided, --selector is not required
  let selectorResult: result<string, parseError> = switch schemaSource {
  | Some(_) => Ok(values.selector->Option.getOr(""))
  | None =>
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
            message:
              `Invalid --extract value "${s}". Valid values are: outerHtml, innerHtml, text, attr:<name>`,
            details: None,
          }),
        )
      }
      switch extractResult {
      | Error(e) => Error(e)
      | Ok(extract) => {
          let modeFromBoolValue = values.mode->Option.getOr(false)
          let mode = modeFromBool(modeFromBoolValue)
          Ok({selector, extract, mode, ?schemaSource})
        }
      }
    }
  }
}
