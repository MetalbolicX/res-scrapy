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
module Iter = NodeIter

/** Counts the number of rows in a JSON result. */
let countRows: JSON.t => int = json => {
  switch json {
  | JSON.Array(arr) => Array.length(arr)
  | _ => 1
  }
}

/** Pre-computed extraction setup so that schema loading (and mode selection)
    happen once per URL-mode run, not once per fetched page. */
type extractionSetup =
  | TableSetup(string)
  | SchemaSetup(Schema.schema)
  | SelectorSetup({selector: string, extract: ParseCli.extractMode, mode: ParseCli.mode})

/** Mutable state threaded through the output-routing calls. */
type outputState = {
  mutable jsonFileStarted: bool,
  mutable jsonRowsWritten: int,
  mutable jsonWriteFailed: bool,
  mutable writeFailures: int,
}

/**
  * Formats a `FieldTypes.schemaError` from schema loading / application into
  * the `reason` string expected by `FetchStatsManager.recordFailure`.
  */
let formatSchemaFailureReason = (err: FieldTypes.schemaError): string =>
  AppError.toMessage(AppError.mapSchemaError(err))

/** Runs the extraction for one document and returns the structured JSON.
    Each branch produces a JSON.t value at the source; no intermediate
    string is materialised for routing purposes. */
let extractFromDocument = (
  ~setup: extractionSetup,
  ~document: NodeHtmlParserBinding.htmlElement,
  ~ctx: AppContext.appContext,
): result<JSON.t, string> => {
  switch setup {
  | TableSetup(selector) =>
    ctx.deps.doc.extractTable(document, selector)->Result.map(rows =>
      JSON.Encode.array(
        rows->Array.map(row =>
          JSON.Encode.object(
            Dict.fromArray(Dict.toArray(row)->Array.map(((k, v)) => (k, JSON.Encode.string(v)))),
          )
        ),
      )
    )
  | SchemaSetup(schema) =>
    ctx.deps.schema.applySchema(document, schema)->Result.mapError(formatSchemaFailureReason)
  | SelectorSetup({selector, extract: extractMode, mode}) =>
    switch SelectorExtractor.extractElements(ctx, document, selector, extractMode, mode) {
    | Error(msg) => Error(msg)
    | Ok(contents) => Ok(JSON.Encode.array(contents->Array.map(JSON.Encode.string)))
    }
  }
}

/** Routes a parsed JSON value to stdout or a file, updating `state`.
    Handles the three output modes (stdout NDJSON, file NDJSON, file JSON streaming)
    in one place so processOne doesn't need the 3-way switch. */
let routeOutput = async (
  ~options: ParseCli.parseOptions,
  ~json: JSON.t,
  ~ctx: AppContext.appContext,
  ~state: outputState,
): unit => {
  switch (options.output, options.outputFormat) {
  | (None, _) =>
    UrlOutputWriter.writeStdoutNdjson(
      ~out=ctx.io.out,
      ~stringifyJson=ctx.deps.serialize.stringifyJson,
      ~json,
    )
  | (Some(path), Ndjson) => {
      let result = await UrlOutputWriter.appendNdjsonToFile(
        ~appendFile=ctx.deps.fs.appendFile,
        ~err=ctx.io.err,
        ~stringifyJson=ctx.deps.serialize.stringifyJson,
        ~path,
        ~json,
      )
      switch result {
      | Ok(_) => ()
      | Error(_) => state.writeFailures = state.writeFailures + 1
      }
    }
  | (Some(path), Json) =>
    // Framing state advances only after a successful write. After any
    // JSON-path write failure the file is left untouched for the rest of
    // the run (it may be truncated): a partially-written row cannot be
    // repaired by further appends, so surface the failure through exit 1
    // and the existing warning instead.
    if !state.jsonWriteFailed {
      if !state.jsonFileStarted {
        switch UrlOutputWriter.beginJsonArraySync(
          ~writeFileSync=ctx.deps.fs.writeFileSync,
          ~err=ctx.io.err,
          ~path,
        ) {
        | Ok() => state.jsonFileStarted = true
        | Error(_) => {
            state.writeFailures = state.writeFailures + 1
            state.jsonWriteFailed = true
          }
        }
      }
      if !state.jsonWriteFailed {
        let isFirstRow = state.jsonRowsWritten == 0
        let result = await UrlOutputWriter.appendJsonRowAsync(
          ~appendFile=ctx.deps.fs.appendFile,
          ~err=ctx.io.err,
          ~stringifyJson=ctx.deps.serialize.stringifyJson,
          ~path,
          ~isFirstRow,
          ~json,
        )
        switch result {
        | Ok(_) => state.jsonRowsWritten = state.jsonRowsWritten + countRows(json)
        | Error(_) => {
            state.writeFailures = state.writeFailures + 1
            state.jsonWriteFailed = true
          }
        }
      }
    }
  }
}

/**
  * Formats an `AppError.appError` from `parseDocumentSafely` into the
  * `reason` string expected by `FetchStatsManager.recordFailure`. Preserves
  * the underlying message instead of using a hardcoded fallback.
  */
let formatParseFailureReason = (err: AppError.appError): string => AppError.toMessage(err)

/**
  * Formats a string error from an extraction step (table / selector) into
  * the `reason` string. Pass-through so the caller never loses context.
  */
let formatExtractionFailureReason = (err: string): string => err

let resolveExtractionSetup: (
  AppContext.appContext,
  ParseCli.parseOptions,
) => result<extractionSetup, string> = (ctx, options) =>
  switch ExtractionMode.fromOptions(options) {
  | TableMode(selector) => Ok(TableSetup(selector))
  | SchemaMode(source) =>
    SchemaRunner.loadSchema(ctx, source)
    ->Result.map(schema => SchemaSetup(schema))
    ->Result.mapError(formatSchemaFailureReason)
  | SelectorMode({selector, extract, mode}) => Ok(SelectorSetup({selector, extract, mode}))
  }

/** Runs the per-item pipeline: parse document, extract, route output, update stats.
    Promoted to top-level so it can be unit-tested in isolation. Closure-captured
    state (ctx, options, mgr, state) is now passed explicitly. */
let processOne = async (
  ~setup: extractionSetup,
  ~item: Fetcher.fetchResult,
  ~ctx: AppContext.appContext,
  ~options: ParseCli.parseOptions,
  ~mgr: FetchStatsManager.t,
  ~state: outputState,
) => {
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
    | Ok(document) =>
      switch extractFromDocument(~setup, ~document, ~ctx) {
      | Error(extractErr) =>
        FetchStatsManager.recordFailure(
          mgr,
          ~url,
          ~reason=formatExtractionFailureReason(extractErr),
        )
      | Ok(json) => {
          FetchStatsManager.recordSuccess(mgr, ~rowCount=countRows(json))
          await routeOutput(~options, ~json, ~ctx, ~state)
        }
      }
    }
  }
}

/** Runs URL mode: fetch multiple pages, extract from each, merge results. */
let runUrlMode = async (
  ctx: AppContext.appContext,
  urlTemplate: string,
  options: ParseCli.parseOptions,
) => {
  // Parse URL template
  switch ctx.deps.doc.parseTemplate(urlTemplate)->ResultX.mapError(AppError.mapTemplateError) {
  | Error(err) => {
      ctx.io.err(AppError.toMessage(err))
      ctx.io.exit(1)
    }
  // Exit early if no URLs
  | Ok([]) => {
      ctx.io.err(AppError.toMessage(AppError.CliError("URL template produced no URLs")))
      ctx.io.exit(1)
    }
  | Ok(urls) =>
    switch resolveExtractionSetup(ctx, options) {
    | Error(err) => {
        ctx.io.err(err)
        ctx.io.exit(1)
      }
    | Ok(setup) => {
        // Start timing
        let startTime = ctx.deps.perf.performanceNow()

        // Fetch all pages
        let userAgent =
          options.userAgent->Option.getOr(`res-scrapy/${ctx.deps.cli.getCliVersion()}`)
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
        // 100K row cap) and closed exactly once at the end.
        let mgr = FetchStatsManager.create()
        let state: outputState = {
          jsonFileStarted: false,
          jsonRowsWritten: 0,
          jsonWriteFailed: false,
          writeFailures: 0,
        }

        // Process each fetch result serially. JSON rows must be appended in
        // source order with comma separators between them; serial processing
        // is the simplest way to preserve that ordering without an explicit
        // queue. Stdout / NDJSON paths are also serial here, which keeps
        // file I/O deterministic with negligible cost (Node's libuv
        // serialises writes per FD anyway).
        let rec processAll = async (setup: extractionSetup, idx: int) => {
          if idx >= Array.length(fetchResults) {
            ()
          } else {
            switch Belt.Array.get(fetchResults, idx) {
            | None => ()
            | Some(item) => {
                await processOne(~setup, ~item, ~ctx, ~options, ~mgr, ~state)
                await processAll(setup, idx + 1)
              }
            }
          }
        }
        let _ = await processAll(setup, 0)

        // Calculate duration
        let endTime = ctx.deps.perf.performanceNow()
        let duration = endTime -. startTime
        FetchStatsManager.setDuration(mgr, duration)

        // Close the streamed JSON array. If no rows were ever written the
        // opening bracket was never emitted; in that case we still need to
        // emit an empty array on disk so downstream tools see valid JSON.
        switch (options.output, options.outputFormat) {
        | (Some(path), Json) => {
            if !state.jsonWriteFailed && !state.jsonFileStarted {
              switch UrlOutputWriter.beginJsonArraySync(
                ~writeFileSync=ctx.deps.fs.writeFileSync,
                ~err=ctx.io.err,
                ~path,
              ) {
              | Ok() => state.jsonFileStarted = true
              | Error(_) => {
                  state.writeFailures = state.writeFailures + 1
                  state.jsonWriteFailed = true
                }
              }
            }
            if !state.jsonWriteFailed {
              switch UrlOutputWriter.endJsonArraySync(
                ~appendFileSync=ctx.deps.fs.appendFileSync,
                ~err=ctx.io.err,
                ~path,
              ) {
              | Ok() => ()
              | Error(_) => state.writeFailures = state.writeFailures + 1
              }
            }
          }
        | _ => () // Already streamed
        }

        // Print report to stderr
        FetchStatsManager.printReport(mgr, ~err=ctx.io.err)

        // Exit code: 0 if any succeeded, 1 if all failed or any NDJSON write failed
        if FetchStatsManager.shouldExitWithError(mgr) || state.writeFailures > 0 {
          if state.writeFailures > 0 {
            ctx.io.err(`Warning: ${Int.toString(state.writeFailures)} output write(s) failed`)
          }
          ctx.io.exit(1)
        }
      }
    }
  }
}
