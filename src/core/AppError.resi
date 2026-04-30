type appError =
  | CliError(string)
  | InputError(string)
  | SchemaError(string)
  | ExtractionError(string)
  | FileError(string)
  | WriteError(string)
  | FetchError(string)
  | TemplateError(string)

let mapStdInError: StdIn.stdInError => appError
let mapParseError: ParseCli.parseError => appError
let mapSchemaError: FieldTypes.schemaError => appError
let mapTemplateError: TemplateParser.parseError => appError
let mapFetchError: Fetcher.fetchError => appError
let toMessage: appError => string
