/** Bindings to the global `fetch` API (available in Node.js >= 18). */
type dispatcher

/** AbortSignal for fetch timeout control. */
module AbortSignal = {
  type t
  type controller

  @new external makeController: unit => controller = "AbortController"
  @get external signal: controller => t = "signal"
  @send external abort: controller => unit = "abort"
  /** True when the signal has been aborted (e.g. via the timeout controller).
    * Used to classify fetch failures as timeouts instead of fragile message
    * string-matching on the exception. */
  @get external aborted: t => bool = "aborted"
}

/** Represents an HTTP response from `fetch`. */
type response = {
  ok: bool,
  status: int,
  statusText: string,
}

/** Extracts the response body as text. */
@send external text: response => promise<string> = "text"

/** Configuration object for fetch requests. */
type options = {
  method?: string,
  headers?: dict<string>,
  signal?: AbortSignal.t,
  dispatcher?: dispatcher,
}

/** Performs an HTTP request using the global `fetch` API. */
@val external fetch: (string, option<options>) => promise<response> = "fetch"
