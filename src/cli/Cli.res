let showHelp: unit => unit = () => {
  Console.log(`
  Usage: res-scrapy command [options]
    -h, --help        Display this help message
    -s, --selector    Specify a CSS selector to extract data
    -m, --mode        Specify the mode to extract data, single or multiple
    -t, --text        Extract text instead of attributes
    -c, --schema      Specify the schema to use
    -p, --schemaPath  Specify the path to the schema
  `)
  NodeJsBinding.Process.exit(0)
}

let parse: unit => NodeJsBinding.Util.cliValues = () => {
  open NodeJsBinding.Util
  let options = Dict.fromArray([
    ("mode", {type_: "string", short: "m", default: String("single")}),
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
