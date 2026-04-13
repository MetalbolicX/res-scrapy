type extractionMode =
  | TableMode(string)
  | SchemaMode(ParseCli.schemaSource)
  | SelectorMode({
      selector: string,
      extract: ParseCli.extractMode,
      mode: ParseCli.mode,
    })

let fromOptions: ParseCli.parseOptions => extractionMode
