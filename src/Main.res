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

let isExecutedAsScript: unit => bool = %raw(`() => {
    try {
      if (typeof process === "undefined" || !process.argv || process.argv.length < 2) {
        return false;
      }
      const currentPath = new URL(import.meta.url).pathname;
      const invokedPath = process.argv[1];
      return currentPath === invokedPath || decodeURIComponent(currentPath) === invokedPath;
    } catch {
      return false;
    }
  }`)

/** Register global Node.js event handlers for uncaught exceptions, unhandled
  * rejections, and termination signals. Guards against double-registration via a
  * globalThis flag.
  *
  * INTENTIONAL FFI ISLAND — typed rewrite would require per-event externals and
  * still leave the formatError helper as raw. The raw block is self-contained and
  * isolated. See docs/architecture.md §15.
  */
let registerGlobalRuntimeHandlers: (
  string => unit,
  int => unit,
) => unit = %raw(`(report, exitFn) => {
    if (globalThis.__resScrapyRuntimeHandlersRegistered) {
      return;
    }
    globalThis.__resScrapyRuntimeHandlersRegistered = true;

    const formatError = (value) => {
      if (value && typeof value === "object") {
        if (typeof value.stack === "string") return value.stack;
        if (typeof value.message === "string") return value.message;
      }
      return String(value);
    };

    process.on("uncaughtException", (err) => {
      report("Unexpected runtime error:");
      report(formatError(err));
      exitFn(1);
    });

    process.on("unhandledRejection", (reason) => {
      report("Unhandled promise rejection:");
      report(formatError(reason));
      exitFn(1);
    });

    process.on("SIGINT", () => {
      report("Interrupted (SIGINT)");
      exitFn(130);
    });

    process.on("SIGTERM", () => {
      report("Terminated (SIGTERM)");
      exitFn(143);
    });
  }`)

if isExecutedAsScript() {
  registerGlobalRuntimeHandlers(Console.error, NodeProcess.setExitCode)
  await main()
}
