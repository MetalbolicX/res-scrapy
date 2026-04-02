let showHelp: unit => unit = () => {
  Console.log(`
  Usage: res-scrapy command [options]
    -h, --help      Display this help message
    -s, --selector  Specify a CSS selector to extract data
    -m, --mode      Specify the mode to extract data, single or multiple
    -t, --text      Extract text instead of attributes
    -c, --schema    Specify the schema to use
    -p, --schemaPath Specify the path to the schema
  `)
  Bindings.Process.exit(0)
}


let parse: unit => Bindings.Util.cliArgs = () => {
  let config = {
    "args": Bindings.Process.argv->Array.slice(~start=2),
    "allowPositionals": false,
    "options": {
      "help": { "type": "boolean", "short": "h" },
      "selector": { "type": "string", "short": "s", "default": "" },
      "mode": { "type": "string", "short": "m", "default": "single" },
      "text": { "type": "boolean", "short": "t", "default": false },
      "schema": { "type": "string", "short": "c", "default": "" },
      "schemaPath": { "type": "string", "short": "p", "default": "" },
    },
    "strict": false,
  }
  let args = Bindings.Util.parseArgs(config)
  let values = args["values"]

  if (values.help === Nullable.make(true)) {
    showHelp()
  }

  values
}
