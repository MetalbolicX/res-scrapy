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

let modeFromString: string => result<mode, string> = text =>
  switch text {
  | "single" => Ok(Single)
  | "multiple" => Ok(Multiple)
  | other => Error(`Unknown mode: "${other}". Valid values are "single" or "multiple"`)
  }

let runArgsValidation: NodeJsBinding.Util.cliValues => result<
  parseOptions,
  parseError,
> = values => {
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
}
