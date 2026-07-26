/**
  * Bindings to the Node.js `process` global.
  *
  * Only the surface needed by this CLI is exposed. Extend here when new
  * `process.*` APIs are required rather than adding ad-hoc `%raw` calls.
  */
/** Terminates the process with the given numeric exit code. */
@val @scope("process") external exit: int => unit = "exit"

/** Sets `process.exitCode` so Node exits naturally after pending writes complete. */
let setExitCode: int => unit = %raw(`code => { process.exitCode = code; }`)

/** The command-line argument vector; `argv[0]` is `node`, `argv[1]` is the script. */
@val @scope("process") external argv: array<string> = "argv"

/**
  * Represents the `process.stdin` readable stream.
  *
  * `isTTY` is `Some(true)` when stdin is a terminal (interactive), `None`
  * when it is a pipe or redirected file — used to detect piped input.
 */
type stdInput = {
  isTTY?: bool,
}

/** A reference to `process.stdin`. */
@val @scope("process") external stdin: stdInput = "stdin"

/** The absolute path to the current Node.js executable. */
@val @scope("process") external execPath: string = "execPath"

/** Listens for `"data"` events, invoking `cb` with each UTF-8 chunk. */
@send external onData: (stdInput, @as("data") _, string => unit) => unit = "on"

/** Listens for the `"end"` event, invoked once the stream is fully consumed. */
@send external onEnd: (stdInput, @as("end") _, unit => unit) => unit = "on"

/** Listens for `"error"` events on the stream. */
@send external onError: (stdInput, @as("error") _, JsExn.t => unit) => unit = "on"

/** Resumes a paused readable stream, allowing data events to flow. */
@send external resume: stdInput => unit = "resume"

/** Sets the character encoding for data events (e.g. `"utf8"`). */
@send external setEncoding: (stdInput, string) => unit = "setEncoding"
