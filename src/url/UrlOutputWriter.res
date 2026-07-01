/**
  * UrlOutputWriter — URL-mode output routing.
  *
  * Three responsibilities, all behavior-preserving with the prior
  * monolithic UrlRunner implementation:
  *   1. Stream NDJSON rows directly to stdout (no buffering).
  *   2. Append NDJSON rows to a file asynchronously; on failure, emit a
  *      warning via the supplied error function rather than aborting.
  *   3. Synchronously write a buffered JSON array to a file. Used when the
  *      cumulative row count stays under the 100_000 cap.
  *
  * Functions take only the I/O callbacks they need (`out`, `appendFile`,
  * `writeFileSync`) plus a `stringifyJson` helper. This keeps the module
  * testable without an AppContext and prevents fanout updates when the
  * orchestration layer changes.
  *
  * The 100_000 row cap and the buffered/allResults bookkeeping still live
  * in UrlRunner. UrlOutputWriter is invoked only after the orchestration
  * decides which path to take; it does not make those routing decisions.
  */

/** Wraps the small JSON helpers that distinguish an array vs. a bare value. */
let extractJsonArray: JSON.t => array<JSON.t> = json =>
  switch json {
  | JSON.Array(arr) => arr
  | _ => [json]
  }

/** Writes NDJSON to stdout by iterating over a JSON array. Each row is
    serialised on the fly; nothing is accumulated in memory. */
let writeStdoutNdjson: (~out: string => unit, ~stringifyJson: JSON.t => string, ~json: JSON.t) => unit = (
  ~out,
  ~stringifyJson,
  ~json,
) => {
  let rows = extractJsonArray(json)
  rows->Array.forEach(row => out(stringifyJson(row)))
}

/** Appends NDJSON rows to a file asynchronously. If appendFile throws, the
    warning is emitted on `err` and the returned promise resolves to
    `Error(msg)` so the caller can surface a non-zero exit code while the
    overall run continues for the remaining writes. */
let appendNdjsonToFile: (
  ~appendFile: (string, string) => promise<unit>,
  ~err: string => unit,
  ~stringifyJson: JSON.t => string,
  ~path: string,
  ~json: JSON.t,
) => promise<result<unit, string>> = async (~appendFile, ~err, ~stringifyJson, ~path, ~json) => {
  let rows = extractJsonArray(json)
  let content = rows->Array.map(stringifyJson)->Array.join("\n") ++ "\n"
  try {
    await appendFile(path, content)
    Ok(())
  } catch {
  | exn =>
    let msg = `Failed to append to output file "${path}": ${ExnUtils.message(exn)}`
    err(`Warning: ${msg}`)
    Error(msg)
  }
}

/** Synchronously writes a buffered JSON array to a file. The caller is
    responsible for the cap-check and the actual row flatMap before this
    is invoked; UrlOutputWriter simply encodes the array and writes. */
let writeFileJsonSync: (
  ~writeFileSync: (string, string) => unit,
  ~err: string => unit,
  ~stringifyJson: JSON.t => string,
  ~path: string,
  ~rows: array<JSON.t>,
) => result<unit, AppError.appError> = (~writeFileSync, ~err, ~stringifyJson, ~path, ~rows) => {
  let json = JSON.Encode.array(rows)
  let jsonText = stringifyJson(json)
  switch OutputWriter.computeOutputText(~target=OutputWriter.File(path), ~jsonText, ~format=ParseCli.Json) {
  | Error(e) => Error(e)
  | Ok(text) =>
    OutputWriter.writeText(~target=OutputWriter.File(path), ~text, ~writeFile=writeFileSync, ~out=err)
  }
}
