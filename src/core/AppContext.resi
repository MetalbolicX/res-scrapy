type dependencies = {
  parseCli: unit => NodeJsBinding.Util.cliValues,
  validateArgs: NodeJsBinding.Util.cliValues => result<ParseCli.parseOptions, ParseCli.parseError>,
  readStdin: unit => promise<Result.t<string, StdIn.stdInError>>,
  documentOps: Document.operations,
  extractTable: (Document.document, string) => result<array<dict<string>>, string>,
  loadSchema: (~isInline: bool, string) => result<Schema.schema, FieldTypes.schemaError>,
  applySchema: (Document.document, Schema.schema) => result<JSON.t, FieldTypes.schemaError>,
  writeFile: (string, string) => unit,
  stringifyJson: JSON.t => string,
  stringifyTableRows: array<dict<string>> => string,
  stringifyStrings: array<string> => string,
}

type io = {
  out: string => unit,
  err: string => unit,
  warn: string => unit,
  exit: int => unit,
}

type appContext = {
  deps: dependencies,
  io: io,
}

let production: appContext
