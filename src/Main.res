/**
  * Entry point for the res-scrapy CLI.
  *
  * Flow:
  * 1. Parse and validate CLI flags via `Cli` and `ParseCli`.
  * 2. Read HTML from stdin via `StdIn`.
  * 3a. When `--schema`/`--schemaPath` is provided: load and apply the schema via
  *     `Schema`, outputting a JSON array of row objects.
  * 3b. Otherwise: extract elements matching `--selector` in `--mode single|multiple`,
  *     returning text content or outer HTML per `--text`.
  * 4. Write the JSON result to stdout; exit with code 1 on any error.
 */
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
          switch options.schemaSource {
          // -----------------------------------------------------------------
          // Schema-driven structured extraction
          // -----------------------------------------------------------------
          | Some(schemaSource) => {
              let schemaResult = switch schemaSource {
              | InlineJson(raw) => Schema.loadSchema(~isInline=true, raw)
              | FilePath(path) => Schema.loadSchema(~isInline=false, path)
              }
              switch schemaResult {
              | Error(InvalidJson(msg))
              | Error(MissingFields(msg))
              | Error(FileReadError(msg))
              | Error(AttributeMissingKey(msg))
              | Error(ExtractionError(msg))
              | Error(RequiredFieldMissing({fieldName: msg, selector: _})) => {
                  Console.error(msg)
                  NodeJsBinding.Process.exit(1)
                }
              | Error(InvalidFieldType({field, got})) => {
                  Console.error(`Invalid field type "${got}" for field "${field}"`)
                  NodeJsBinding.Process.exit(1)
                }
              | Ok(schema) =>
                switch Schema.applySchema(document, schema) {
                | Error(RequiredFieldMissing({fieldName, selector})) => {
                    Console.error(
                      `Required field "${fieldName}" not found for selector "${selector}"`,
                    )
                    NodeJsBinding.Process.exit(1)
                  }
                | Error(InvalidJson(msg))
                | Error(MissingFields(msg))
                | Error(FileReadError(msg))
                | Error(AttributeMissingKey(msg)) => {
                    Console.error(msg)
                    NodeJsBinding.Process.exit(1)
                  }
                | Error(ExtractionError(msg)) => {
                    Console.error(msg)
                    NodeJsBinding.Process.exit(1)
                  }
                | Error(InvalidFieldType({field, got})) => {
                    Console.error(`Invalid field type "${got}" for field "${field}"`)
                    NodeJsBinding.Process.exit(1)
                  }
                | Ok(json) => Console.log(NodeJsBinding.jsonStringify(json))
                }
              }
            }
          // -----------------------------------------------------------------
          // Selector-driven simple extraction
          // -----------------------------------------------------------------
          | None => {
              let extract = (el: NodeHtmlParserBinding.htmlElement) =>
                switch options.extract {
                | OuterHtml => el.outerHTML
                | InnerHtml => el.innerHTML
                | Text => el.textContent
                | Attribute(name) =>
                  el->NodeHtmlParserBinding.getAttribute(name)->Nullable.toOption->Option.getOr("")
                }
              let contents: array<string> = switch options.mode {
              | Single =>
                switch document
                ->NodeHtmlParserBinding.querySelector(options.selector)
                ->Nullable.toOption {
                | None => []
                | Some(el) => [extract(el)]
                }
              | Multiple =>
                document
                ->NodeHtmlParserBinding.querySelectorAll(options.selector)
                ->Array.map(el => extract(el))
              }
              Console.log(contents->NodeJsBinding.jsonStringify)
            }
          }
        }
      }
    }
  }
}

await main()
