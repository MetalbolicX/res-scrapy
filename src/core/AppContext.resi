type cliDeps = {
  parseCli: unit => NodeUtil.cliValues,
  validateArgs: NodeUtil.cliValues => result<ParseCli.parseOptions, ParseCli.parseError>,
  readStdin: unit => promise<Result.t<string, StdIn.stdInError>>,
  getCliVersion: unit => string,
}

type fsDeps = {
  writeFile: (string, string) => promise<unit>,
  appendFile: (string, string) => promise<unit>,
  writeFileSync: (string, string) => unit,
  appendFileSync: (string, string) => unit,
}

type serializeDeps = {
  stringifyJson: JSON.t => string,
  stringifyTableRows: array<dict<string>> => string,
  stringifyStrings: array<string> => string,
}

type docDeps = {
  documentOps: Document.operations,
  extractTable: (Document.document, string) => result<array<dict<string>>, string>,
  parseTemplate: string => result<array<string>, TemplateParser.parseError>,
}

type schemaDeps = {
  loadSchema: (~isInline: bool, string) => result<Schema.schema, FieldTypes.schemaError>,
  applySchema: (Document.document, Schema.schema) => result<JSON.t, FieldTypes.schemaError>,
}

type fetchDeps = {
  fetchAll: (array<string>, Fetcher.fetchOptions) => promise<array<Fetcher.fetchResult>>,
}

type perfDeps = {
  performanceNow: unit => float,
}

type dependencies = {
  cli: cliDeps,
  fs: fsDeps,
  serialize: serializeDeps,
  doc: docDeps,
  schema: schemaDeps,
  fetch: fetchDeps,
  perf: perfDeps,
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

let exitWithError: (appContext, AppError.appError) => unit
let production: appContext
