type appError =
  | CliError(string)
  | InputError(string)
  | SchemaError(string)
  | ExtractionError(string)
  | FileError(string)
  | WriteError(string)
  | FetchError(string)
  | TemplateError(string)

let mapStdInError: StdIn.stdInError => appError = err =>
  switch err {
  | NoInput(msg) => InputError(msg)
  | EmptyContent(msg) => InputError(msg)
  | ReadError(msg) => InputError(msg)
  }

let mapParseError: ParseCli.parseError => appError = err =>
  switch err {
  | MissingSelector(msg) => CliError(msg)
  | ParseError({message}) => CliError(message)
  | NoMatches({message}) => CliError(message)
  | InvalidConcurrency(msg) => CliError(msg)
  | InvalidTimeout(msg) => CliError(msg)
  | InvalidRetry(msg) => CliError(msg)
  | InvalidDelay(msg) => CliError(msg)
  | InvalidHeader(msg) => CliError(msg)
  | InvalidUrlMode(msg) => CliError(msg)
  }

let mapSchemaError: FieldTypes.schemaError => appError = err =>
  switch err {
  | FieldTypes.InvalidJson(msg) => SchemaError(msg)
  | FieldTypes.MissingFields(msg) => SchemaError(msg)
  | FieldTypes.InvalidFieldType({field, got}) =>
    SchemaError(`Invalid field type "${got}" for field "${field}"`)
  | FieldTypes.AttributeMissingKey(msg) => SchemaError(msg)
  | FieldTypes.FileReadError(msg) => FileError(msg)
  | FieldTypes.RequiredFieldMissing({fieldName, selector}) =>
    ExtractionError(`Required field "${fieldName}" not found for selector "${selector}"`)
  | FieldTypes.ExtractionError(msg) => ExtractionError(msg)
  }

let mapTemplateError: TemplateParser.parseError => appError = err =>
  switch err {
  | InvalidSyntax(msg) => TemplateError(msg)
  | InvalidRange(msg) => TemplateError(msg)
  }

let mapFetchError: Fetcher.fetchError => appError = err =>
  switch err {
  | NetworkError(msg) => FetchError(msg)
  | Timeout(msg) => FetchError(msg)
  | HttpError(status, msg) => FetchError(`HTTP ${Int.toString(status)}: ${msg}`)
  | ParseError(msg) => FetchError(msg)
  }

let toMessage: appError => string = err =>
  switch err {
  | CliError(msg)
  | InputError(msg)
  | SchemaError(msg)
  | ExtractionError(msg)
  | FileError(msg)
  | WriteError(msg)
  | FetchError(msg)
  | TemplateError(msg) => msg
  }
