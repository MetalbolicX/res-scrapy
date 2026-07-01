/**
  * ExnUtils — small helpers for working with JavaScript / ReScript exceptions.
  *
  * Two-tier API:
  * - `message(exn)`: a short, single-line string suitable for end-user
  *   rendering. Falls back to "Unknown error".
  * - `fullMessage(exn)`: a richer representation that includes the JS stack
  *   trace when available. Used for diagnostics where the underlying call
  *   path matters (e.g. structured error output in run-reporting).
  *
  * `fullMessage` deliberately degrades gracefully — when the exception has
  * no stack trace (e.g. a ReScript-side exception that wraps a primitive,
  * or an exception with an empty stack), `fullMessage` falls back to
  * `message` rather than emitting placeholder text.
  */

let message = exn =>
  switch exn->JsExn.fromException {
  | Some(jsExn) => jsExn->JsExn.message->Option.getOr("Unknown error")
  | None => "Unknown error"
  }

/* `stack` is a thin binding over the optional `stack` property on a JS error
   object. It returns `None` for any value that isn't a JS exception. */
@get external getStack: JsExn.t => option<string> = "stack"

let stack: JsExn.t => option<string> = getStack

let fromExn: exn => option<JsExn.t> = exn => exn->JsExn.fromException

/** Returns the message plus the stack (if any) as a single multiline string. */
let fullMessage = exn =>
  switch exn->fromExn {
  | None => "Unknown error"
  | Some(jsExn) => {
      let m = jsExn->JsExn.message->Option.getOr("Unknown error")
      switch stack(jsExn) {
      | None => m
      | Some(s) if s === "" => m
      | Some(s) => `${m}\n${s}`
      }
    }
  }
