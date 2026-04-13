type appError =
  | CliError(string)
  | InputError(string)
  | SchemaError(string)
  | ExtractionError(string)
  | FileError(string)

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

let toMessage: appError => string = err =>
  switch err {
  | CliError(msg)
  | InputError(msg)
  | SchemaError(msg)
  | ExtractionError(msg)
  | FileError(msg) => msg
  }
