type mode = Single | Multiple

type parseOptions = {
  selector: string,
  extractText: bool,
  mode: mode,
}

type parseError =
  | MissingSelector(string)
  | ParseError({message: string, details: option<JsExn.t>})
  | NoMatches({message: string, selector: string})

/**
  * Converts a string to a mode, returning an error if the string is not a valid mode
  * Valid modes are "single" and "multiple"
  * The error message includes the invalid value and the list of valid values

 */
let modeFromString: string => result<mode, string> = text =>
  switch text {
  | "single" => Ok(Single)
  | "multiple" => Ok(Multiple)
  | other => Error(`Unknown mode: "${other}". Valid values are "single" or "multiple"`)
  }

/**
  * Validates the command line arguments and returns either a parseOptions object or a parseError
  * Checks that the selector is provided and not empty
  * Checks that the mode is valid if provided, defaulting to "single"
 */
let runArgsValidation: NodeJsBinding.Util.cliValues => result<parseOptions, parseError> = values =>
  switch values.selector {
  | None | Some("") => Error(MissingSelector("Selector is required (--selector/-s)"))
  | Some(selector) => {
      let extractText = values.text->Option.getOr(false)
      let modeText = values.mode->Option.getOr("single")
      switch modeFromString(modeText) {
      | Ok(mode) => Ok({selector, extractText, mode})
      | Error(msg) => Error(ParseError({message: msg, details: None}))
      }
    }
  }
