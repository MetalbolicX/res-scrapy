open ParseCli

type extractionMode =
  | TableMode(string)
  | SchemaMode(schemaSource)
  | SelectorMode({selector: string, extract: extractMode, mode: mode})

let fromOptions: parseOptions => extractionMode = options =>
  switch options.schemaSource {
  | Some(TableSelector(selector)) => TableMode(selector)
  | Some(source) => SchemaMode(source)
  | None => SelectorMode({selector: options.selector, extract: options.extract, mode: options.mode})
  }
