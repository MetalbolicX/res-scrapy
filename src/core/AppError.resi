type appError =
  | CliError(string)
  | InputError(string)
  | SchemaError(string)
  | ExtractionError(string)
  | FileError(string)
  | WriteError(string)

let mapStdInError: StdIn.stdInError => appError
let mapParseError: ParseCli.parseError => appError
let mapSchemaError: FieldTypes.schemaError => appError
let toMessage: appError => string
