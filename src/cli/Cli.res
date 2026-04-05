/**
  * CLI help message and argument parsing logic
 */
let showHelp: unit => unit = () => {
  Console.log(`
  Usage: res-scrapy command [options]
    -h, --help        Display this help message
    -s, --selector    Specify a CSS selector to extract data
    -m, --mode        Extract multiple results (single by default)
    -t, --text        Extract text instead of attributes
    -c, --schema      Specify the schema to use
    -p, --schemaPath  Specify the path to the schema
  `)
  NodeJsBinding.Process.exit(0)
}

/**
  * Parses the command line arguments using NodeJsBinding.Util.parseArgs and returns the values
  * If the help flag is present, it shows the help message and exits
  * The expected arguments are:
  * --selector/-s: a required string argument specifying the CSS selector to use for scraping
  * --mode/-m: an optional boolean flag indicating whether to extract multiple results (false by default for single result)
  * --text/-t: an optional boolean flag indicating whether to extract text content instead of outer HTML, defaulting to false
  * --schema/-c: an optional string argument specifying the schema to use for validation
  * --schemaPath/-p: an optional string argument specifying the path to the schema file
  * The function returns an object containing the parsed values for these arguments, which can then be validated and used in the main logic of the application
 */
let parse: unit => NodeJsBinding.Util.cliValues = () => {
  open NodeJsBinding.Util
  let options = Dict.fromArray([
    ("mode", {type_: "boolean", short: "m", default: Bool(false)}),
    ("selector", {type_: "string", short: "s"}),
    ("text", {type_: "boolean", short: "t", default: Bool(false)}),
    ("schema", {type_: "string", short: "c"}),
    ("schemaPath", {type_: "string", short: "p"}),
    ("help", {type_: "boolean", short: "h"}),
  ])

  let args = parseArgs({
    args: NodeJsBinding.Process.argv->Array.slice(~start=2),
    allowPositionals: false,
    options,
    strict: true,
    tokens: true,
  })
  let {values} = args

  switch values.help {
  | Some(true) => showHelp()
  | _ => ()
  }

  values
}
