module Iter = NodeJsBinding.Iter

/** Extracts element content from a document using selector + extract mode.
  * Returns array of strings for Single/Multiple mode. */
let extractElements: (
  AppContext.appContext,
  Document.document,
  string,
  ParseCli.extractMode,
  ParseCli.mode,
) => result<array<string>, string> = (ctx, document, selector, extractMode, mode) => {
  let extract = (el: Document.element) =>
    switch extractMode {
    | OuterHtml => Document.outerHTML(ctx.deps.doc.documentOps, el)
    | InnerHtml => Document.innerHTML(ctx.deps.doc.documentOps, el)
    | Text => Document.textContent(ctx.deps.doc.documentOps, el)
    | Attribute(name) => Document.getAttribute(ctx.deps.doc.documentOps, el, name)->Option.getOr("")
    }
  switch mode {
  | Single =>
    switch Document.querySelector(ctx.deps.doc.documentOps, document, selector) {
    | None => Ok([])
    | Some(el) => Ok([extract(el)])
    }
  | Multiple =>
    Ok(
      Document.querySelectorAll(ctx.deps.doc.documentOps, document, selector)
      ->Iter.values
      ->Iter.map(el => extract(el))
      ->Iter.toArray,
    )
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
  switch extractElements(ctx, document, selector, extractMode, mode) {
  | Error(msg) => AppContext.exitWithError(ctx, AppError.ExtractionError(msg))
  | Ok(contents) =>
    switch (mode, contents) {
    | (ParseCli.Single, []) => OutputWriter.writeOutput(ctx, options, "null")
    | _ => OutputWriter.writeOutput(ctx, options, ctx.deps.serialize.stringifyStrings(contents))
    }
  }
}
