let main: unit => promise<unit> = async () => {
  let config = Cli.parse()
  switch ParseCli.runArgsValidation(config) {
  | Error(MissingSelector(msg)) => {
      Console.error(msg)
      NodeJsBinding.Process.exit(1)
    }
  | Error(ParseError({message: msg})) => {
      Console.error(msg)
      NodeJsBinding.Process.exit(1)
    }
  | Error(NoMatches({message: msg})) => {
      Console.error(msg)
      NodeJsBinding.Process.exit(1)
    }
  | Ok(options) => {
      let stdinResult = await StdIn.readFromStdin()
      switch stdinResult {
      | Error(NoInput(msg)) | Error(EmptyContent(msg)) | Error(ReadError(msg)) => {
          Console.error(msg)
          NodeJsBinding.Process.exit(1)
        }
      | Ok(html) => {
          let document = NodeHtmlParserBinding.parse(html)
          let contents: array<string> = switch options.mode {
          | Single =>
            switch document
            ->NodeHtmlParserBinding.querySelector(options.selector)
            ->Nullable.toOption {
            | None => []
            | Some(el) => [options.extractText ? el.textContent : el.outerHTML]
            }
          | Multiple =>
            document
            ->NodeHtmlParserBinding.querySelectorAll(options.selector)
            ->Array.map(el => options.extractText ? el.textContent : el.outerHTML)
          }
          Console.log(contents->NodeJsBinding.jsonStringify)
        }
      }
    }
  }
}

await main()
