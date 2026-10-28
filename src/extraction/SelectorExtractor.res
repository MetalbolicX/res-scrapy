module Iter = NodeIter

/** Matches processed between event-loop yields in Multiple mode. JS signal
  * handlers cannot run while the main thread is busy, so without the yield a
  * SIGTERM during a large extraction is deferred until it finishes. */
let batchYieldSize = 5000

/** Maps `items` in order, awaiting `yieldFn` after every `batchSize` items
  * (never after the last item) so pending signal handlers can run between
  * batches. A plain loop keeps the call stack flat for any batch size. */
let mapInBatches = async (
  items: array<'a>,
  ~batchSize: int,
  ~yieldFn: unit => promise<unit>,
  f: 'a => 'b,
): array<'b> => {
  let total = Array.length(items)
  let out: array<'b> = []
  for i in 0 to total - 1 {
    out->Array.push(f(items->Array.getUnsafe(i)))
    if mod(i + 1, batchSize) == 0 && i + 1 < total {
      await yieldFn()
    }
  }
  out
}

/** Extracts element content from a document using selector + extract mode.
  * Returns array of strings for Single/Multiple mode. Multiple mode yields to
  * the event loop between batches so pending signal handlers can run. */
let extractElements: (
  AppContext.appContext,
  Document.document,
  string,
  ParseCli.extractMode,
  ParseCli.mode,
) => promise<result<array<string>, string>> = async (
  ctx,
  document,
  selector,
  extractMode,
  mode,
) => {
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
      await mapInBatches(
        Document.querySelectorAll(ctx.deps.doc.documentOps, document, selector),
        ~batchSize=batchYieldSize,
        ~yieldFn=NodeProcess.yieldToEventLoop,
        extract,
      ),
    )
  }
}

let runSelectorMode = async (
  ctx: AppContext.appContext,
  document: Document.document,
  ~selector: string,
  ~extractMode: ParseCli.extractMode,
  ~mode: ParseCli.mode,
  ~options: ParseCli.parseOptions,
): promise<unit> => {
  let outcome = await extractElements(ctx, document, selector, extractMode, mode)
  switch outcome {
  | Error(msg) => AppContext.exitWithError(ctx, AppError.ExtractionError(msg))->Promise.resolve
  | Ok(contents) =>
    OutputWriter.writeOutput(
      ctx,
      options,
      ctx.deps.serialize.stringifyStrings(contents),
    )->Promise.resolve
  }
}
