/**
  * CLI help message and argument parsing logic
 */
@get_index external getObjectKey: ({..}, string) => option<'a> = ""

module Iter = NodeJsBinding.Iter

let candidatePackagePaths: unit => array<string> = %raw(`() => {
  try {
    return [
      decodeURIComponent(new URL('../package.json', import.meta.url).pathname),
      decodeURIComponent(new URL('../../package.json', import.meta.url).pathname),
    ];
  } catch {
    return [];
  }
}`)

let parseVersionFromPath: string => option<string> = path => {
  try {
    let raw = NodeJsBinding.Fs.readFileSync(path)
    switch NodeJsBinding.jsonParse(raw) {
    | None => None
    | Some(json) => {
        let pkg: {..} = Obj.magic(json)
        getObjectKey(pkg, "version")
      }
    }
  } catch {
  | _ => None
  }
}

let getCliVersion: unit => string = () => {
  let paths = candidatePackagePaths()
  let found: ref<option<string>> = ref(None)
  paths->Iter.values->Iter.forEach(path => {
    if found.contents->Option.isNone {
      found := parseVersionFromPath(path)
    }
  })
  found.contents->Option.getOr("unknown")
}

let showHelp: unit => unit = () => {
  Console.log(`
  Usage: res-scrapy [options]
    -v, --version      Display CLI version
    -h, --help         Display this help message
    -s, --selector     Specify a CSS selector to extract data
    -m, --mode         Extract multiple results (single by default)
    -e, --extract      What to extract: outerHtml (default), innerHtml, text, or attr:<name>
    -c, --schema       Specify the schema to use
    -p, --schemaPath   Specify the path to the schema
    -t, --table        Extract a table as JSON; pair with --selector to target a specific table (defaults to "table")
    -o, --output       Write output to a file instead of stdout
    -f, --format       Output format for file writes: json (default) or ndjson
    -u, --url          URL or URL template (e.g., https://site.com/page={1..10})
    -j, --concurrency  Max concurrent fetches (default: 5, max: 20)
    --user-agent       Override the HTTP User-Agent header for URL mode
    --timeout          Request timeout in seconds for URL mode (default: 30)
    --retry            Max retry attempts for URL mode (default: 3)
    --delay            Delay in milliseconds between URL request starts (default: 0)
    --header           Add request header for URL mode; repeatable (e.g. --header 'Accept: text/html')
    --cookie           Add Cookie header value for URL mode; repeatable
  `)
  NodeJsBinding.Process.exit(0)
}

/**
  * Parses the command line arguments using NodeJsBinding.Util.parseArgs and returns the values
  * If the help flag is present, it shows the help message and exits
  * The expected arguments are:
  * --selector/-s: a required string argument specifying the CSS selector to use for scraping
  * --mode/-m: an optional boolean flag indicating whether to extract multiple results (false by default for single result)
  * --extract/-e: an optional string argument indicating what to extract (outerHtml, innerHtml, text, attr:<name>)
  * --schema/-c: an optional string argument specifying the schema to use for validation
  * --schemaPath/-p: an optional string argument specifying the path to the schema file
  * --table/-t: an optional boolean flag to extract a table as JSON (uses --selector, defaults to "table")
  * The function returns an object containing the parsed values for these arguments, which can then be validated and used in the main logic of the application
 */
let parse: unit => NodeJsBinding.Util.cliValues = () => {
  open NodeJsBinding.Util
  let options = Dict.fromArray([
    ("version", {type_: "boolean", short: "v", default: Bool(false)}),
    ("mode", {type_: "boolean", short: "m", default: Bool(false)}),
    ("selector", {type_: "string", short: "s"}),
    ("extract", {type_: "string", short: "e", default: String("outerHtml")}),
    ("schema", {type_: "string", short: "c"}),
    ("schemaPath", {type_: "string", short: "p"}),
    ("table", {type_: "boolean", short: "t", default: Bool(false)}),
    ("output", {type_: "string", short: "o"}),
    ("format", {type_: "string", short: "f", default: String("json")}),
    ("url", {type_: "string", short: "u"}),
    ("concurrency", {type_: "string", short: "j", default: String("5")}),
    ("userAgent", {type_: "string"}),
    ("timeout", {type_: "string", default: String("30")}),
    ("retry", {type_: "string", default: String("3")}),
    ("delay", {type_: "string", default: String("0")}),
    ("header", {type_: "string", multiple: true}),
    ("cookie", {type_: "string", multiple: true}),
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

  switch values.version {
  | Some(true) => {
      Console.log(getCliVersion())
      NodeJsBinding.Process.exit(0)
    }
  | _ => ()
  }

  values
}
