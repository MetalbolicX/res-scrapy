module Iter = NodeJsBinding.Iter

/** Extracts results from a JSON value, handling both arrays and single objects. */
let extractJsonArray: JSON.t => array<JSON.t> = json => {
  switch json {
  | JSON.Array(arr) => arr
  | _ => [json]
  }
}

/** Counts the number of rows in a JSON result. */
let countRows: JSON.t => int = json => {
  switch json {
  | JSON.Array(arr) => Array.length(arr)
  | _ => 1
  }
}

/**
  * Formats an `AppError.appError` from `parseDocumentSafely` into the
  * `reason` string expected by `Reporter.recordFailure`. Preserves the
  * underlying message instead of using a hardcoded fallback.
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
  * the `reason` string expected by `Reporter.recordFailure`.
  */
let formatSchemaFailureReason = (err: FieldTypes.schemaError): string =>
  AppError.toMessage(AppError.mapSchemaError(err))

/** Writes NDJSON to stdout by iterating over a JSON array. */
let writeNdjsonToStdout: (AppContext.appContext, JSON.t) => unit = (ctx, json) => {
  let rows = extractJsonArray(json)
  rows->Array.forEach(row => {
    ctx.io.out(ctx.deps.stringifyJson(row))
  })
}

/** Appends NDJSON rows to a file asynchronously. */
let appendNdjsonToFile: (AppContext.appContext, string, JSON.t) => promise<unit> = async (ctx, path, json) => {
  let rows = extractJsonArray(json)
  let content = rows->Array.map(ctx.deps.stringifyJson)->Array.join("\n") ++ "\n"
  try {
    await ctx.deps.appendFile(path, content)
  } catch {
  | exn =>
    ctx.io.err(`Warning: Failed to append to output file "${path}": ${ExnUtils.message(exn)}`)
  }
}

/** Runs URL mode: fetch multiple pages, extract from each, merge results. */
let runUrlMode = async (
  ctx: AppContext.appContext,
  urlTemplate: string,
  options: ParseCli.parseOptions,
) => {
  // Parse URL template
  let urls = switch ctx.deps.parseTemplate(urlTemplate)->ResultX.mapError(AppError.mapTemplateError) {
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
    let startTime = ctx.deps.performanceNow()

    // Fetch all pages
    let userAgent = options.userAgent->Option.getOr(`res-scrapy/${ctx.deps.getCliVersion()}`)
    let fetchOptions: Fetcher.fetchOptions = {
      concurrency: options.concurrency,
      userAgent,
      timeoutSeconds: options.timeoutSeconds,
      retryCount: options.retryCount,
      delayMs: options.delayMs,
      headers: options.requestHeaders->Array.map(h => (h.name, h.value)),
    }
    let fetchResults = await ctx.deps.fetchAll(urls, fetchOptions)

    // Initialize stats, output accumulator, and pending write promises
    let stats = ref(Reporter.empty())
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
          stats := Reporter.recordFailure(stats.contents, ~url, ~reason)
        }
      | Ok(html) => {
          // Parse document
          switch Document.parseDocumentSafely(ctx.deps.documentOps, html) {
          | Error(parseErr) => {
              stats := Reporter.recordFailure(
                stats.contents,
                ~url,
                ~reason=formatParseFailureReason(parseErr),
              )
            }
          | Ok(document) => {
              // Extract data
              let extractionResult = switch ExtractionMode.fromOptions(options) {
              | TableMode(selector) => ctx.deps.extractTable(document, selector)->Result.map(ctx.deps.stringifyTableRows)
              | SchemaMode(source) =>
                SchemaRunner.loadSchema(ctx, source)
                ->ResultX.flatMap(schema => ctx.deps.applySchema(document, schema))
                ->Result.map(ctx.deps.stringifyJson)
                ->Result.mapError(formatSchemaFailureReason)
              | SelectorMode({selector, extract: extractMode, mode}) =>
                  switch SelectorExtractor.extractElements(ctx, document, selector, extractMode, mode) {
                  | Error(msg) => Error(msg)
                  | Ok(contents) => Ok(ctx.deps.stringifyStrings(contents))
                  }
              }

              switch extractionResult {
              | Error(extractErr) => {
                  stats := Reporter.recordFailure(
                    stats.contents,
                    ~url,
                    ~reason=formatExtractionFailureReason(extractErr),
                  )
                }
              | Ok(jsonText) => {
                  // Parse JSON to count rows
                  switch NodeJsBinding.jsonParse(jsonText) {
                  | Some(json) => {
                      let rowCount = countRows(json)
                      stats := Reporter.recordSuccess(stats.contents, ~rowCount)

                      // For streaming output, write immediately
                      switch (options.output, options.outputFormat) {
                      | (None, _) => writeNdjsonToStdout(ctx, json) // stdout always streams NDJSON
                      | (Some(path), Ndjson) => pendingWrites := list{appendNdjsonToFile(ctx, path, json), ...pendingWrites.contents}
                      | (Some(_), Json) =>
                        if jsonOutputHitCap.contents {
                          () // Already at cap, discard rows silently
                        } else {
                          let batchRows = countRows(json)
                          if totalRowCount.contents + batchRows > 100_000 {
                            ctx.io.err("Warning: JSON output exceeds 100,000 rows; capping and continuing without this batch.")
                            jsonOutputHitCap := true
                          } else {
                            totalRowCount := totalRowCount.contents + batchRows
                            allResults := list{extractJsonArray(json), ...allResults.contents}
                          }
                        }
                      }
                    }
                  | None => {
                      stats := Reporter.recordFailure(stats.contents, ~url, ~reason="Failed to parse extraction result")
                    }
                  }
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
    let endTime = ctx.deps.performanceNow()
    let duration = endTime -. startTime
    stats := Reporter.setDuration(stats.contents, duration)

    // Write buffered results for file JSON output
    switch (options.output, options.outputFormat) {
    | (Some(path), Json) => {
        let flatResults = allResults.contents->List.reverse->List.toArray->Array.flat
        let json = JSON.Encode.array(flatResults)
        let jsonText = ctx.deps.stringifyJson(json)
        switch await OutputWriter.writeAsync(
          ~target=OutputWriter.File(path),
          ~format=Json,
          ~jsonText,
          ~writeFile=ctx.deps.writeFile,
          ~out=ctx.io.out,
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
    Reporter.printReport(stats.contents, ~err=ctx.io.err)

    // Exit code: 0 if any succeeded, 1 if all failed
    if stats.contents.succeeded == 0 && stats.contents.failed > 0 {
      ctx.io.exit(1)
    }
  }
}