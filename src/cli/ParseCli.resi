type mode = Single | Multiple

type schemaSource =
  | InlineJson(string)
  | FilePath(string)

type parseOptions = {
  selector: string,
  extractText: bool,
  mode: mode,
  schemaSource?: schemaSource,
}

type parseError =
  | MissingSelector(string)
  | ParseError({message: string, details: option<JsExn.t>})
  | NoMatches({message: string, selector: string})

let runArgsValidation: NodeJsBinding.Util.cliValues => result<parseOptions, parseError>
