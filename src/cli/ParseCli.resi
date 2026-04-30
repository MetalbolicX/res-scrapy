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

type headerEntry = {
  name: string,
  value: string,
}

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

let runArgsValidation: NodeJsBinding.Util.cliValues => result<parseOptions, parseError>
