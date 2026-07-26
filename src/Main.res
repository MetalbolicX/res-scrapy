let exitWithError = AppContext.exitWithError

let parseCliSafely = (ctx: AppContext.appContext): result<
  ParseCli.parseOptions,
  AppError.appError,
> => {
  try {
    ctx.deps.cli.parseCli()->ctx.deps.cli.validateArgs->ResultX.mapError(AppError.mapParseError)
  } catch {
  | exn => Error(AppError.CliError(`Invalid CLI arguments: ${ExnUtils.message(exn)}`))
  }
}

let emitWarnings = (ctx: AppContext.appContext, options: ParseCli.parseOptions) =>
  options.warnings->Array.forEach(ctx.io.warn)

let mainWithContext: AppContext.appContext => promise<unit> = async ctx => {
  try {
    let parsed = parseCliSafely(ctx)
    switch parsed {
    | Error(err) => exitWithError(ctx, err)
    | Ok(options) => {
        emitWarnings(ctx, options)

        // Check if URL mode or stdin mode
        switch options.url {
        | Some(urlTemplate) =>
          // URL mode: fetch pages and extract
          await UrlRunner.runUrlMode(ctx, urlTemplate, options)
        | None => {
            // Stdin mode: existing behavior
            let stdinResult = await ctx.deps.cli.readStdin()
            switch stdinResult->ResultX.mapError(AppError.mapStdInError) {
            | Error(err) => exitWithError(ctx, err)
            | Ok(html) =>
              switch Document.parseDocumentSafely(ctx.deps.doc.documentOps, html) {
              | Error(err) => exitWithError(ctx, err)
              | Ok(document) =>
                switch ExtractionMode.fromOptions(options) {
                | TableMode(selector) => TableRunner.runTableMode(ctx, document, selector, options)
                | SchemaMode(source) => SchemaRunner.runSchemaMode(ctx, document, source, options)
                | SelectorMode({selector, extract, mode}) =>
                  SelectorExtractor.runSelectorMode(
                    ctx,
                    document,
                    ~selector,
                    ~extractMode=extract,
                    ~mode,
                    ~options,
                  )
                }
              }
            }
          }
        }
      }
    }
  } catch {
  | exn =>
    exitWithError(ctx, AppError.ExtractionError(`Unexpected error: ${ExnUtils.message(exn)}`))
  }
}

let main: unit => promise<unit> = () => mainWithContext(AppContext.production)

let isExecutedAsScript = ImportMetaBinding.isExecutedAsScript

/** Register global Node.js event handlers for uncaught exceptions, unhandled
  * rejections, and termination signals. Delegates to the typed binding in
  * src/bindings/NodeProcess.res.
  */
let registerGlobalRuntimeHandlers = NodeProcess.registerGlobalRuntimeHandlers

if isExecutedAsScript() {
  registerGlobalRuntimeHandlers(Console.error, NodeProcess.setExitCode)
  await main()
}
