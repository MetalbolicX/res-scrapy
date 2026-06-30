/**
  * UrlRunner — orchestration for URL-mode extraction.
  *
  * After the PR 2b split, UrlRunner is responsible only for the fetch →
  * extract → fail/retry control flow. Three concern-orthogonal moves:
  *
  *   • Output routing — delegated to `UrlOutputWriter`
  *     (writeStdoutNdjson / appendNdjsonToFile / writeFileJsonSync).
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

/* Helper bridge: exposes UrlOutputWriter.extractJsonArray without exporting
   the OutputWriter helpers. Used by the orchestration loop when buffering
   JSON output rows that pass the cap check. */
let urlOutputExtractJsonArray: JSON.t => array<JSON.t> = json =>
  switch json {
  | JSON.Array(arr) => arr
  | _ => [json]
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

/* JSON output cap. Beyond this, JSON file output is silently dropped
   while NDJSON streaming / writeFile paths continue. */
let jsonOutputRowCap = 100_000

/** Runs URL mode: fetch multiple pages, extract from each, merge results. */
let runUrlMode = async (
  ctx: AppContext.appContext,
  urlTemplate: string,
  options: ParseCli.parseOptions,
) => {
  // Parse URL template
  let urls = switch ctx.deps.doc.parseTemplate(urlTemplate)->ResultX.mapError(AppError.mapTemplateError) {
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
    let userAgent = options.userAgent->Option.getOr(`res-scrapy/${ctx.deps.cli.getCliVersion()}`)
    let fetchOptions: Fetcher.fetchOptions = {
      concurrency: options.concurrency,
      userAgent,
      timeoutSeconds: options.timeoutSeconds,
      retryCount: options.retryCount,
      delayMs: options.delayMs,
      headers: options.requestHeaders->Array.map(h => (h.name, h.value)),
    }
    let fetchResults = await ctx.deps.fetch.fetchAll(urls, fetchOptions)

    // Initialise stats (FetchStatsManager) and output accumulators
    let mgr = FetchStatsManager.create()
    let allResults = ref(list{})
    let totalRowCount = ref(0)
    let pendingWrites: ref<list<promise<unit>>> = ref(list{})
    let jsonOutputHitCap = ref(false)

    // Process each fetch result
    fetchResults->Array.forEach(({url, result}) => {
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
        | Ok(html) => {
          // Parse document
          switch Document.parseDocumentSafely(ctx.deps.doc.documentOps, html) {
          | Error(parseErr) =>
            FetchStatsManager.recordFailure(
              mgr,
              ~url,
              ~reason=formatParseFailureReason(parseErr),
            )
          | Ok(document) => {
              // Extract data
              let extractionResult = switch ExtractionMode.fromOptions(options) {
              | TableMode(selector) => ctx.deps.doc.extractTable(document, selector)->Result.map(ctx.deps.serialize.stringifyTableRows)
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
                    | (Some(_), Json) =>
                      if jsonOutputHitCap.contents {
                        () // Already at cap, discard rows silently
                      } else {
                        let batchRows = countRows(json)
                        if totalRowCount.contents + batchRows > jsonOutputRowCap {
                          ctx.io.err("Warning: JSON output exceeds 100,000 rows; capping and continuing without this batch.")
                          jsonOutputHitCap := true
                        } else {
                          totalRowCount := totalRowCount.contents + batchRows
                          let rows = urlOutputExtractJsonArray(json)
                          allResults := list{rows, ...allResults.contents}
                        }
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
    })

    // Await all pending file writes
    let writes = pendingWrites.contents->List.reverse->List.toArray
    if Array.length(writes) > 0 {
      let _ = await Promise.all(writes)
    }

    // Calculate duration
    let endTime = ctx.deps.perf.performanceNow()
    let duration = endTime -. startTime
    FetchStatsManager.setDuration(mgr, duration)

    // Write buffered results for file JSON output
    switch (options.output, options.outputFormat) {
    | (Some(path), Json) => {
        let flatResults = allResults.contents->List.reverse->List.toArray->Array.flat
        switch UrlOutputWriter.writeFileJsonSync(
          ~writeFileSync=ctx.deps.fs.writeFileSync,
          ~err=ctx.io.err,
          ~stringifyJson=ctx.deps.serialize.stringifyJson,
          ~path,
          ~rows=flatResults,
        ) {
        | Ok(()) => ()
        | Error(err) => {
            ctx.io.err(AppError.toMessage(err))
            ctx.io.exit(1)
          }
        }
      }
    | _ => () // Already streamed
    }

    // Print report to stderr
    FetchStatsManager.printReport(mgr, ~err=ctx.io.err)

    // Exit code: 0 if any succeeded, 1 if all failed
    if FetchStatsManager.shouldExitWithError(mgr) {
      ctx.io.exit(1)
    }
  }
}
