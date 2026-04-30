type dependencies = {
  parseCli: unit => NodeJsBinding.Util.cliValues,
  validateArgs: NodeJsBinding.Util.cliValues => result<ParseCli.parseOptions, ParseCli.parseError>,
  readStdin: unit => promise<Result.t<string, StdIn.stdInError>>,
  documentOps: Document.operations,
  extractTable: (Document.document, string) => result<array<dict<string>>, string>,
  loadSchema: (~isInline: bool, string) => result<Schema.schema, FieldTypes.schemaError>,
  applySchema: (Document.document, Schema.schema) => result<JSON.t, FieldTypes.schemaError>,
  writeFile: (string, string) => unit,
  appendFile: (string, string) => unit,
  stringifyJson: JSON.t => string,
  stringifyTableRows: array<dict<string>> => string,
  stringifyStrings: array<string> => string,
  parseTemplate: string => result<array<string>, TemplateParser.parseError>,
  fetchAll: (array<string>, Fetcher.fetchOptions) => promise<array<Fetcher.fetchResult>>,
  getCliVersion: unit => string,
  performanceNow: unit => float,
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

let production: appContext = {
  deps: {
    parseCli: Cli.parse,
    validateArgs: ParseCli.runArgsValidation,
    readStdin: StdIn.readFromStdin,
    documentOps: NodeHtmlDocument.operations,
    extractTable: TableExtractor.extract,
    loadSchema: Schema.loadSchema,
    applySchema: Schema.applySchema,
    writeFile: NodeJsBinding.Fs.writeFileSync,
    appendFile: NodeJsBinding.Fs.appendFileSync,
    stringifyJson: NodeJsBinding.jsonStringify,
    stringifyTableRows: NodeJsBinding.jsonStringify,
    stringifyStrings: NodeJsBinding.jsonStringify,
    parseTemplate: TemplateParser.parse,
    fetchAll: Fetcher.fetchAll,
    getCliVersion: Cli.getCliVersion,
    performanceNow: NodeJsBinding.Performance.now,
  },
  io: {
    out: Console.log,
    err: Console.error,
    warn: Console.error,
    exit: NodeJsBinding.Process.setExitCode,
  },
}
