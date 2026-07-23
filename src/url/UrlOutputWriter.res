/**
  * UrlOutputWriter — URL-mode output routing.
  *
  * Three responsibilities, all behavior-preserving with the prior
  * monolithic UrlRunner implementation:
  *   1. Stream NDJSON rows directly to stdout (no buffering).
  *   2. Append NDJSON rows to a file asynchronously; on failure, emit a
  *      warning via the supplied error function rather than aborting.
  *   3. Stream a JSON array to a file: initialise with the opening
  *      bracket, append each batch of rows with comma separators, then
  *      close with the trailing bracket. No rows are buffered in memory.
  *
  * Functions take only the I/O callbacks they need (`out`, `appendFile`,
  * `writeFileSync`) plus a `stringifyJson` helper. This keeps the module
  * testable without an AppContext and prevents fanout updates when the
  * orchestration layer changes.
  *
  * URL-mode orchestration lives in UrlRunner. UrlOutputWriter is invoked
  * with the I/O callbacks only; it does not make routing decisions.
  */
/** Wraps the small JSON helpers that distinguish an array vs. a bare value. */
let extractJsonArray: JSON.t => array<JSON.t> = json =>
  switch json {
  | JSON.Array(arr) => arr
  | _ => [json]
  }

/** Wraps a failed file operation: emits a warning via `err` and returns Error.
    Shared by all sync write helpers to keep error wording consistent. */
let emitWriteError = (~err, ~path, ~operation, ~exn): result<unit, AppError.appError> => {
  let msg = `${operation} "${path}": ${ExnUtils.message(exn)}`
  err(`Warning: ${msg}`)
  Error(AppError.WriteError(msg))
}

/** Writes NDJSON to stdout by iterating over a JSON array. Each row is
    serialised on the fly; nothing is accumulated in memory. */
let writeStdoutNdjson: (
  ~out: string => unit,
  ~stringifyJson: JSON.t => string,
  ~json: JSON.t,
) => unit = (~out, ~stringifyJson, ~json) => {
  let rows = extractJsonArray(json)
  rows->Array.forEach(row => out(stringifyJson(row)))
}

/** Appends NDJSON rows to a file asynchronously. If appendFile throws, the
    warning is emitted on `err` and the returned promise resolves to
    `Error(appErr)` so the caller can surface a non-zero exit code while the
    overall run continues for the remaining writes. */
let appendNdjsonToFile: (
  ~appendFile: (string, string) => promise<unit>,
  ~err: string => unit,
  ~stringifyJson: JSON.t => string,
  ~path: string,
  ~json: JSON.t,
) => promise<result<unit, AppError.appError>> = async (~appendFile, ~err, ~stringifyJson, ~path, ~json) => {
  let rows = extractJsonArray(json)
  let content = rows->Array.map(stringifyJson)->Array.join("\n") ++ "\n"
  try {
    await appendFile(path, content)
    Ok()
  } catch {
  | exn => emitWriteError(~err, ~path, ~operation="Failed to append to output file", ~exn)
  }
}

/** Synchronously writes the opening bracket of a streamed JSON array.
    On failure, emits a warning via `err` and resolves to `Error(appErr)` so
    the caller can surface a non-zero exit code. */
let beginJsonArraySync: (
  ~writeFileSync: (string, string) => unit,
  ~err: string => unit,
  ~path: string,
) => result<unit, AppError.appError> = (~writeFileSync, ~err, ~path) => {
  try {
    writeFileSync(path, "[")
    Ok()
  } catch {
  | exn => emitWriteError(~err, ~path, ~operation="Failed to open JSON output file", ~exn)
  }
}

/** Appends JSON rows to a streamed array file. Rows are comma-separated
    to form valid JSON; the very first row of the file (when `isFirstRow`
    is `true`) is prefixed with no extra comma, while subsequent rows are
    always comma-prefixed. On failure, emits a warning via `err` and
    resolves to `Error(appErr)`. */
let appendJsonRowAsync: (
  ~appendFile: (string, string) => promise<unit>,
  ~err: string => unit,
  ~stringifyJson: JSON.t => string,
  ~path: string,
  ~isFirstRow: bool,
  ~json: JSON.t,
) => promise<result<unit, AppError.appError>> = async (
  ~appendFile,
  ~err,
  ~stringifyJson,
  ~path,
  ~isFirstRow,
  ~json,
) => {
  let rows = extractJsonArray(json)
  let joined = rows->Array.map(stringifyJson)->Array.join(",")
  let content = isFirstRow ? joined : "," ++ joined
  try {
    await appendFile(path, content)
    Ok()
  } catch {
  | exn => emitWriteError(~err, ~path, ~operation="Failed to append to JSON output file", ~exn)
  }
}

/** Synchronously writes the closing bracket of a streamed JSON array.
    On failure, emits a warning via `err` and resolves to `Error(appErr)`. */
let endJsonArraySync: (
  ~appendFileSync: (string, string) => unit,
  ~err: string => unit,
  ~path: string,
) => result<unit, AppError.appError> = (~appendFileSync, ~err, ~path) => {
  try {
    appendFileSync(path, "]")
    Ok()
  } catch {
  | exn => emitWriteError(~err, ~path, ~operation="Failed to close JSON output file", ~exn)
  }
}

/** Synchronously writes a buffered JSON array to a file. Retained for
    backwards compatibility with code paths that already hold all rows in
    memory (e.g. schema-style extraction). The streaming helpers above are
    preferred for URL-mode output. */
let writeFileJsonSync: (
  ~writeFileSync: (string, string) => unit,
  ~err: string => unit,
  ~stringifyJson: JSON.t => string,
  ~path: string,
  ~rows: array<JSON.t>,
) => result<unit, AppError.appError> = (~writeFileSync, ~err, ~stringifyJson, ~path, ~rows) => {
  let json = JSON.Encode.array(rows)
  let jsonText = stringifyJson(json)
  switch OutputWriter.computeOutputText(
    ~target=OutputWriter.File(path),
    ~jsonText,
    ~format=ParseCli.Json,
  ) {
  | Error(e) => Error(e)
  | Ok(text) =>
    OutputWriter.writeText(
      ~target=OutputWriter.File(path),
      ~text,
      ~writeFile=writeFileSync,
      ~out=err,
    )
  }
}
