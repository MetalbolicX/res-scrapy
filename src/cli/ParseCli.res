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

/**
  * Validated, fully-typed options produced by `runArgsValidation`.
  *
  * - `selector`     — CSS selector; always non-empty.
  * - `extractText`  — when `true`, use `.textContent`; otherwise `.outerHTML`.
  * - `mode`         — `Single` (first match) or `Multiple` (all matches).
  * - `schemaSource` — optional structured-extraction descriptor; takes precedence
  *                    over `selector`/`mode`/`extractText` when present.
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
  // Resolve schema source first — it supersedes selector/mode/text flags
  let schemaSource: option<schemaSource> = switch (values.schema, values.schemaPath) {
  | (Some(s), _) if s != "" => Some(InlineJson(s))
  | (_, Some(p)) if p != "" => Some(FilePath(p))
  | _ => None
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
      let extract: extractMode = switch values.extract->Option.getOr("outerHtml") {
      | "outerHtml" => OuterHtml
      | "innerHtml" => InnerHtml
      | "text" => Text
      | s if String.startsWith(s, "attr:") =>
        Attribute(String.slice(s, ~start=5, ~end=String.length(s)))
      | _ => OuterHtml
      }
      let modeFromBoolValue = values.mode->Option.getOr(false)
      let mode = modeFromBool(modeFromBoolValue)
      Ok({selector, extract, mode, ?schemaSource})
    }
  }
}
