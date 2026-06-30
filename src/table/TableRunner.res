let runTableMode = (
  ctx: AppContext.appContext,
  document: Document.document,
  selector: string,
  options: ParseCli.parseOptions,
) => {
  switch ctx.deps.doc.extractTable(document, selector) {
  | Error(msg) => {
 ctx.io.err(AppError.toMessage(AppError.ExtractionError(msg)))
      ctx.io.exit(1)
    }
  | Ok(rows) => OutputWriter.writeOutput(ctx, options, ctx.deps.serialize.stringifyTableRows(rows))
  }
}