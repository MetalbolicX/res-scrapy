/**
  * UrlRunner — orchestration for URL-mode extraction.
  *
  * After the PR 2b split, UrlRunner is responsible only for the fetch →
  * extract → fail/retry control flow. Three concern-orthogonal moves:
  *
  *   • Output routing — delegated to `UrlOutputWriter`
  *     (writeStdoutNdjson, appendNdjsonToFile, and the streaming
  *     beginJsonArraySync / appendJsonRowAsync / endJsonArraySync trio).
  *   • Stats aggregation — delegated to `FetchStatsManager`,
  *     which wraps the existing `Reporter` record types.
  *   • JSON helpers — kept in this file because they are tiny and used
  *     only by the orchestrator (e.g. counting rows in a JSON array).
  */

module Iter = NodeJsBinding.Iter

/** Counts the number of rows in a JSON result. */
let countRows: JSON.t => int = json => {
  switch json {
  | JSON.Array(arr) => Array.length(arr)
  | _ => 1
  }
}

/**
  * Formats an `AppError.appError` from `parseDocumentSafely` into the
  * `reason` string expected by `FetchStatsManager.recordFailure`. Preserves
  * the underlying message instead of using a hardcoded fallback.
  */
let formatParseFailureReason = (err: AppError.appError): string =>
  AppError.toMessage(err)

/**
  * Formats a string error from an extraction step (table / selector) into
  * the `reason` string. Pass-through so the caller never loses context.
  */
let formatExtractionFailureReason = (err: string): string => err

/**
  * Formats a `FieldTypes.schemaError` from schema loading / application into
  * the `reason` string expected by `FetchStatsManager.recordFailure`.
  */
let formatSchemaFailureReason = (err: FieldTypes.schemaError): string =>
  AppError.toMessage(AppError.mapSchemaError(err))

/** Runs URL mode: fetch multiple pages, extract from each, merge results. */
let runUrlMode = async (
  ctx: AppContext.appContext,
  urlTemplate: string,
  options: ParseCli.parseOptions,
) => {
  // Parse URL template
  let urls = switch ctx.deps.doc
    .parseTemplate(urlTemplate)
    ->ResultX.mapError(AppError.mapTemplateError) {
  | Error(err) => {
      ctx.io.err(AppError.toMessage(err))
      ctx.io.exit(1)
      []
    }
  | Ok(urls) => urls
  }

  // Exit early if no URLs
  if Array.length(urls) == 0 {
    ctx.io.err(AppError.toMessage(AppError.CliError("URL template produced no URLs")))
    ctx.io.exit(1)
  } else {
    // Start timing
    let startTime = ctx.deps.perf.performanceNow()

    // Fetch all pages
    let userAgent = options.userAgent->Option.getOr(
      `res-scrapy/${ctx.deps.cli.getCliVersion()}`,
    )
    let fetchOptions: Fetcher.fetchOptions = {
      concurrency: options.concurrency,
      userAgent,
      timeoutSeconds: options.timeoutSeconds,
      retryCount: options.retryCount,
      delayMs: options.delayMs,
      headers: options.requestHeaders->Array.map(h => (h.name, h.value)),
    }
    let fetchResults = await ctx.deps.fetch.fetchAll(urls, fetchOptions)

    // Initialise stats and streaming output state. JSON file output is
    // opened lazily on the first successful batch (no pre-allocation, no
    // 100K row cap) and closed exactly once at the end. NDJSON writes are
    // dispatched into `pendingWrites` and awaited together at the end.
    let mgr = FetchStatsManager.create()
    let pendingWrites: ref<list<promise<result<unit, string>>>> = ref(list{})
    let writeFailures = ref(0)
    let jsonFileStarted: ref<bool> = ref(false)
    let jsonRowsWritten: ref<int> = ref(0)

    // Process each fetch result serially. JSON rows must be appended in
    // source order with comma separators between them; serial processing
    // is the simplest way to preserve that ordering without an explicit
    // queue. Stdout / NDJSON paths are also serial here, which keeps
    // file I/O deterministic with negligible cost (Node's libuv
    // serialises writes per FD anyway).
    let processOne = async (item: Fetcher.fetchResult) => {
      let {url, result} = item
      switch result {
      | Error(fetchErr) => {
          let reason = switch fetchErr {
          | NetworkError(msg) => msg
          | Timeout(msg) => msg
          | HttpError(status, msg) => `HTTP ${Int.toString(status)}: ${msg}`
          | ParseError(msg) => msg
          }
          FetchStatsManager.recordFailure(mgr, ~url, ~reason)
        }
      | Ok(html) =>
        switch Document.parseDocumentSafely(ctx.deps.doc.documentOps, html) {
        | Error(parseErr) =>
          FetchStatsManager.recordFailure(mgr, ~url, ~reason=formatParseFailureReason(parseErr))
        | Ok(document) => {
            // Extract data
            let extractionResult = switch ExtractionMode.fromOptions(options) {
            | TableMode(selector) =>
              ctx.deps.doc
              .extractTable(document, selector)
              ->Result.map(ctx.deps.serialize.stringifyTableRows)
            | SchemaMode(source) =>
              SchemaRunner.loadSchema(ctx, source)
              ->ResultX.flatMap(schema => ctx.deps.schema.applySchema(document, schema))
              ->Result.map(ctx.deps.serialize.stringifyJson)
              ->Result.mapError(formatSchemaFailureReason)
            | SelectorMode({selector, extract: extractMode, mode}) =>
              switch SelectorExtractor.extractElements(ctx, document, selector, extractMode, mode) {
              | Error(msg) => Error(msg)
              | Ok(contents) => Ok(ctx.deps.serialize.stringifyStrings(contents))
              }
            }

            switch extractionResult {
            | Error(extractErr) =>
              FetchStatsManager.recordFailure(
                mgr,
                ~url,
                ~reason=formatExtractionFailureReason(extractErr),
              )
            | Ok(jsonText) =>
              switch NodeJsBinding.jsonParse(jsonText) {
              | Some(json) => {
                  let rowCount = countRows(json)
                  FetchStatsManager.recordSuccess(mgr, ~rowCount)

                  switch (options.output, options.outputFormat) {
                  | (None, _) =>
                    UrlOutputWriter.writeStdoutNdjson(
                      ~out=ctx.io.out,
                      ~stringifyJson=ctx.deps.serialize.stringifyJson,
                      ~json,
                    )
                  | (Some(path), Ndjson) => {
                      let promise = UrlOutputWriter.appendNdjsonToFile(
                        ~appendFile=ctx.deps.fs.appendFile,
                        ~err=ctx.io.err,
                        ~stringifyJson=ctx.deps.serialize.stringifyJson,
                        ~path,
                        ~json,
                      )
                      pendingWrites := list{promise, ...pendingWrites.contents}
                    }
                  | (Some(path), Json) => {
                      if !jsonFileStarted.contents {
                        jsonFileStarted := true
                        switch UrlOutputWriter.beginJsonArraySync(
                          ~writeFileSync=ctx.deps.fs.writeFileSync,
                          ~err=ctx.io.err,
                          ~path,
                        ) {
                        | Ok(()) => ()
                        | Error(_) => writeFailures := writeFailures.contents + 1
                        }
                      }
                      let isFirstRow = jsonRowsWritten.contents == 0
                      jsonRowsWritten := jsonRowsWritten.contents + rowCount
                      let promise = UrlOutputWriter.appendJsonRowAsync(
                        ~appendFile=ctx.deps.fs.appendFile,
                        ~err=ctx.io.err,
                        ~stringifyJson=ctx.deps.serialize.stringifyJson,
                        ~path,
                        ~isFirstRow,
                        ~json,
                      )
                      pendingWrites := list{promise, ...pendingWrites.contents}
                    }
                  }
                }
              | None =>
                FetchStatsManager.recordFailure(
                  mgr,
                  ~url,
                  ~reason="Failed to parse extraction result",
                )
              }
            }
          }
        }
      }
    }

    let rec processAll = async (idx: int) => {
      if idx >= Array.length(fetchResults) {
        ()
      } else {
        switch Belt.Array.get(fetchResults, idx) {
        | None => ()
        | Some(item) =>
          await processOne(item)
          await processAll(idx + 1)
        }
      }
    }
    let _ = await processAll(0)

    // Await all pending file writes (NDJSON streams or JSON appends)
    let writes = pendingWrites.contents->List.reverse->List.toArray
    if Array.length(writes) > 0 {
      let results = await Promise.all(writes)
      results->Array.forEach(result =>
        switch result {
        | Ok(_) => ()
        | Error(_) => writeFailures := writeFailures.contents + 1
        }
      )
    }

    // Calculate duration
    let endTime = ctx.deps.perf.performanceNow()
    let duration = endTime -. startTime
    FetchStatsManager.setDuration(mgr, duration)

    // Close the streamed JSON array. If no rows were ever written the
    // opening bracket was never emitted; in that case we still need to
    // emit an empty array on disk so downstream tools see valid JSON.
    switch (options.output, options.outputFormat) {
    | (Some(path), Json) =>
      if !jsonFileStarted.contents {
        jsonFileStarted := true
        switch UrlOutputWriter.beginJsonArraySync(
          ~writeFileSync=ctx.deps.fs.writeFileSync,
          ~err=ctx.io.err,
          ~path,
        ) {
        | Ok(()) => ()
        | Error(_) => writeFailures := writeFailures.contents + 1
        }
      }
      switch UrlOutputWriter.endJsonArraySync(
        ~writeFileSync=ctx.deps.fs.writeFileSync,
        ~err=ctx.io.err,
        ~path,
      ) {
      | Ok(()) => ()
      | Error(_) => writeFailures := writeFailures.contents + 1
      }
    | _ => () // Already streamed
    }

    // Print report to stderr
    FetchStatsManager.printReport(mgr, ~err=ctx.io.err)

    // Exit code: 0 if any succeeded, 1 if all failed or any NDJSON write failed
    if FetchStatsManager.shouldExitWithError(mgr) || writeFailures.contents > 0 {
      if writeFailures.contents > 0 {
        ctx.io.err(`Warning: ${Int.toString(writeFailures.contents)} output write(s) failed`)
      }
      ctx.io.exit(1)
    }
  }
}
