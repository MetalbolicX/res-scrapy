type mode = Single | Multiple

type extractMode =
  | OuterHtml
  | InnerHtml
  | Text
  | Attribute(string)

type schemaSource =
  | InlineJson(string)
  | FilePath(string)
  | TableSelector(string)

type outputFormat = Json | Ndjson

type parseOptions = {
  selector: string,
  extract: extractMode,
  mode: mode,
  schemaSource?: schemaSource,
  output?: string,
  outputFormat: outputFormat,
  warnings: array<string>,
}

type parseError =
  | MissingSelector(string)
  | ParseError({message: string, details: option<JsExn.t>})
  | NoMatches({message: string, selector: string})

let runArgsValidation: NodeJsBinding.Util.cliValues => result<parseOptions, parseError>
