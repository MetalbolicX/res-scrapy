let exitWithError = (ctx: AppContext.appContext, err: AppError.appError) => {
  ctx.io.err(AppError.toMessage(err))
  ctx.io.exit(1)
}

let hasOnlyAggregateFields = (schema: Schema.schema) =>
  schema.fields->Array.every(((_, field)) =>
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

let runSchemaMode = (
  ctx: AppContext.appContext,
  document: Document.document,
  source: ParseCli.schemaSource,
) => {
  switch loadSchema(ctx, source)->ResultX.mapError(AppError.mapSchemaError) {
  | Error(err) => exitWithError(ctx, err)
  | Ok(schema) => {
      warnIfZipAggregateOnly(ctx, schema)
      switch ctx.deps.applySchema(document, schema)->ResultX.mapError(AppError.mapSchemaError) {
      | Error(err) => exitWithError(ctx, err)
      | Ok(json) => ctx.io.out(ctx.deps.stringifyJson(json))
      }
    }
  }
}

let runTableMode = (
  ctx: AppContext.appContext,
  document: Document.document,
  selector: string,
) => {
  switch ctx.deps.extractTable(document, selector) {
  | Error(msg) => exitWithError(ctx, AppError.ExtractionError(msg))
  | Ok(rows) => ctx.io.out(ctx.deps.stringifyTableRows(rows))
  }
}

let runSelectorMode = (
  ctx: AppContext.appContext,
  document: Document.document,
  ~selector: string,
  ~extractMode: ParseCli.extractMode,
  ~mode: ParseCli.mode,
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
    Document.querySelectorAll(ctx.deps.documentOps, document, selector)->Array.map(el => extract(el))
  }
  ctx.io.out(ctx.deps.stringifyStrings(contents))
}

let mainWithContext: AppContext.appContext => promise<unit> = async ctx => {
  let parsed = ctx.deps.parseCli()->ctx.deps.validateArgs->ResultX.mapError(AppError.mapParseError)
  switch parsed {
  | Error(err) => exitWithError(ctx, err)
  | Ok(options) => {
      let stdinResult = await ctx.deps.readStdin()
      switch stdinResult->ResultX.mapError(AppError.mapStdInError) {
      | Error(err) => exitWithError(ctx, err)
      | Ok(html) => {
          let document = Document.parse(ctx.deps.documentOps, html)
          switch ExtractionMode.fromOptions(options) {
          | TableMode(selector) => runTableMode(ctx, document, selector)
          | SchemaMode(source) => runSchemaMode(ctx, document, source)
          | SelectorMode({selector, extract, mode}) =>
            runSelectorMode(ctx, document, ~selector, ~extractMode=extract, ~mode)
          }
        }
      }
    }
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

if isExecutedAsScript() {
  await main()
}
