type parseOptions = {
  selector: string,
  extractText: bool,
}

type parseError =
  | MissingSelector(string)
  | ParseError({message: string, details: option<JsExn.t>})
  | NoMatches({message: string, selector: string})

let runArgsValidation: NodeJsBinding.Util.cliValues => result<
  parseOptions,
  parseError,
> = values => {
  Console.log(values)
  switch (values.selector, values.text) {
  | (Some(""), _) => Error(MissingSelector("Selector is required"))
  | (Some(selector), Some(text)) => Ok({selector, extractText: text})
  | _ => Error(MissingSelector("Selector is required"))
  }
}
