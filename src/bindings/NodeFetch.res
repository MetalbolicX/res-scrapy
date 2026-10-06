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

/** Headers returned by an HTTP response. */
type responseHeaders

/** Raw Headers.get: real implementations return JS null (not undefined) when
  * the header is absent. ReScript maps undefined to None, so only the null
  * case reaches the wrapper below. */
@send external getHeaderRaw: (responseHeaders, string) => option<string> = "get"

/** JS null as an option-typed value — exported for test fakes that must
  * reproduce real absent-header semantics (Headers.get returns null). */
let jsNull: option<string> = %raw("null")

let isNullValue: 'a => bool = %raw("(x) => x === null")

/** Typed wrapper: strips the JS-null case that ReScript's option mapping does
  * not cover. A 3xx response without a Location header must surface as None
  * (terminal status), never as Some(null) that the URL constructor would
  * resolve into a bogus path. */
let getHeader = (headers: responseHeaders, name: string): option<string> =>
  switch getHeaderRaw(headers, name) {
  | None => None
  | Some(v) => isNullValue(v) ? None : Some(v)
  }

/** Represents an HTTP response from `fetch`. */
type response = {
  ok: bool,
  status: int,
  statusText: string,
  headers: responseHeaders,
}

/** Extracts the response body as text. */
@send external text: response => promise<string> = "text"

/** Configuration object for fetch requests. */
type options = {
  method?: string,
  headers?: dict<string>,
  signal?: AbortSignal.t,
  dispatcher?: dispatcher,
  redirect?: string,
}

/** Performs an HTTP request using the global `fetch` API. */
@val external fetch: (string, option<options>) => promise<response> = "fetch"
