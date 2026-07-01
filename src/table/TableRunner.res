let runTableMode = (
  ctx: AppContext.appContext,
  document: Document.document,
  selector: string,
  options: ParseCli.parseOptions,
) => {
  switch ctx.deps.doc.extractTable(document, selector) {
  | Error(msg) => AppContext.exitWithError(ctx, AppError.ExtractionError(msg))
  | Ok(rows) => OutputWriter.writeOutput(ctx, options, ctx.deps.serialize.stringifyTableRows(rows))
  }
}
