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

let runArgsValidation: NodeJsBinding.Util.cliValues => result<parseOptions, parseError>
