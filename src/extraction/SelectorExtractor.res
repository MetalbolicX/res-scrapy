module Iter = NodeIter

/** Matches processed between event-loop yields in Multiple mode. JS signal
  * handlers cannot run while the main thread is busy, so without the yield a
  * SIGTERM during a large extraction is deferred until it finishes. */
let batchYieldSize = 5000

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
  | Multiple => {
      let elements = Document.querySelectorAll(ctx.deps.doc.documentOps, document, selector)
      let total = Array.length(elements)
      let out: array<string> = []
      let rec loop = async i =>
        if i >= total {
          Ok(out)
        } else {
          out->Array.push(extract(elements->Array.get(i)->Option.getOrThrow))
          if (i + 1) % batchYieldSize == 0 && i + 1 < total {
            await NodeProcess.yieldToEventLoop()
          }
          await loop(i + 1)
        }
      await loop(0)
    }
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
