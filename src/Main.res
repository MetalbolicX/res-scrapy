let exitWithError = (ctx: AppContext.appContext, err: AppError.appError) => {
  ctx.io.err(AppError.toMessage(err))
  ctx.io.exit(1)
}

module Iter = NodeJsBinding.Iter

let parseCliSafely = (ctx: AppContext.appContext): result<ParseCli.parseOptions, AppError.appError> => {
  try {
    ctx.deps.parseCli()->ctx.deps.validateArgs->ResultX.mapError(AppError.mapParseError)
  } catch {
  | exn => Error(AppError.CliError(`Invalid CLI arguments: ${ExnUtils.message(exn)}`))
  }
}

let parseDocumentSafely = (
  ctx: AppContext.appContext,
  html: string,
): result<Document.document, AppError.appError> => {
  try {
    Ok(Document.parse(ctx.deps.documentOps, html))
  } catch {
  | exn => Error(AppError.InputError(`Failed to parse HTML input: ${ExnUtils.message(exn)}`))
  }
}

let hasOnlyAggregateFields = (schema: Schema.schema) =>
  schema.fields->Iter.values->Iter.every(((_, field)) =>
    switch field.fieldType {
    | Count(_) | List(_) => true
    | _ => false
    }
  )

let warnIfZipAggregateOnly = (ctx: AppContext.appContext, schema: Schema.schema) => {
  let isZipMode = switch schema.config.rowSelector {
  | None => true
  | Some(_) => false
  }
  if isZipMode && hasOnlyAggregateFields(schema) {
    ctx.io.warn(
      "Warning: schema uses zip mode (no config.rowSelector) with only aggregate fields (count/list), so no rows can be produced. Add config.rowSelector for row-based extraction.",
    )
  }
}

let loadSchema = (ctx: AppContext.appContext, source: ParseCli.schemaSource) =>
  switch source {
  | InlineJson(raw) => ctx.deps.loadSchema(~isInline=true, raw)
  | FilePath(path) => ctx.deps.loadSchema(~isInline=false, path)
  | TableSelector(_) => Error(FieldTypes.ExtractionError("Unreachable: table mode schema load"))
  }

let outputTargetFromOptions = (options: ParseCli.parseOptions): OutputWriter.outputTarget =>
  switch options.output {
  | Some(path) => File(path)
  | None => Stdout
  }

let writeOutput = (
  ctx: AppContext.appContext,
  options: ParseCli.parseOptions,
  jsonText: string,
) => {
  switch OutputWriter.write(
    ~target=outputTargetFromOptions(options),
    ~format=options.outputFormat,
    ~jsonText,
    ~writeFile=ctx.deps.writeFile,
    ~out=ctx.io.out,
  ) {
  | Ok(()) => ()
  | Error(err) => exitWithError(ctx, err)
  }
}

let runSchemaMode = (
  ctx: AppContext.appContext,
  document: Document.document,
  source: ParseCli.schemaSource,
  options: ParseCli.parseOptions,
) => {
  switch loadSchema(ctx, source)->ResultX.mapError(AppError.mapSchemaError) {
  | Error(err) => exitWithError(ctx, err)
  | Ok(schema) => {
      warnIfZipAggregateOnly(ctx, schema)
      switch ctx.deps.applySchema(document, schema)->ResultX.mapError(AppError.mapSchemaError) {
      | Error(err) => exitWithError(ctx, err)
      | Ok(json) => writeOutput(ctx, options, ctx.deps.stringifyJson(json))
      }
    }
  }
}

let runTableMode = (
  ctx: AppContext.appContext,
  document: Document.document,
  selector: string,
  options: ParseCli.parseOptions,
) => {
  switch ctx.deps.extractTable(document, selector) {
  | Error(msg) => exitWithError(ctx, AppError.ExtractionError(msg))
  | Ok(rows) => writeOutput(ctx, options, ctx.deps.stringifyTableRows(rows))
  }
}

let runSelectorMode = (
  ctx: AppContext.appContext,
  document: Document.document,
  ~selector: string,
  ~extractMode: ParseCli.extractMode,
  ~mode: ParseCli.mode,
  ~options: ParseCli.parseOptions,
) => {
  let extract = (el: Document.element) =>
    switch extractMode {
    | OuterHtml => Document.outerHTML(ctx.deps.documentOps, el)
    | InnerHtml => Document.innerHTML(ctx.deps.documentOps, el)
    | Text => Document.textContent(ctx.deps.documentOps, el)
    | Attribute(name) =>
      Document.getAttribute(ctx.deps.documentOps, el, name)->Option.getOr("")
    }
  let contents: array<string> = switch mode {
  | Single =>
    switch Document.querySelector(ctx.deps.documentOps, document, selector) {
    | None => []
    | Some(el) => [extract(el)]
    }
  | Multiple =>
    Document.querySelectorAll(ctx.deps.documentOps, document, selector)
    ->Iter.values
    ->Iter.map(el => extract(el))
    ->Iter.toArray
  }
  writeOutput(ctx, options, ctx.deps.stringifyStrings(contents))
}

let mainWithContext: AppContext.appContext => promise<unit> = async ctx => {
  try {
    let parsed = parseCliSafely(ctx)
    switch parsed {
    | Error(err) => exitWithError(ctx, err)
    | Ok(options) => {
        let stdinResult = await ctx.deps.readStdin()
        switch stdinResult->ResultX.mapError(AppError.mapStdInError) {
        | Error(err) => exitWithError(ctx, err)
        | Ok(html) => {
            switch parseDocumentSafely(ctx, html) {
            | Error(err) => exitWithError(ctx, err)
            | Ok(document) =>
              switch ExtractionMode.fromOptions(options) {
              | TableMode(selector) => runTableMode(ctx, document, selector, options)
              | SchemaMode(source) => runSchemaMode(ctx, document, source, options)
              | SelectorMode({selector, extract, mode}) =>
                runSelectorMode(ctx, document, ~selector, ~extractMode=extract, ~mode, ~options)
              }
            }
          }
        }
      }
    }
  } catch {
  | exn => exitWithError(ctx, AppError.ExtractionError(`Unexpected error: ${ExnUtils.message(exn)}`))
  }
}

let main: unit => promise<unit> = () => mainWithContext(AppContext.production)

let isExecutedAsScript: unit => bool =
  %raw(`() => {
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

let registerGlobalRuntimeHandlers: (string => unit, int => unit) => unit =
  %raw(`(report, exitFn) => {
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
  registerGlobalRuntimeHandlers(Console.error, NodeJsBinding.Process.setExitCode)
  await main()
}
