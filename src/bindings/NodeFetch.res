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

/** Best-effort release of bodies that will not be consumed. */
let cancelBody: response => promise<unit> = %raw(`async response => {
  try { await response.body?.cancel(); } catch (_) { /* preserve original outcome */ }
}`)

/** Extracts the response body as text. */
@send external text: response => promise<string> = "text"

type arrayBuffer
type byteView
@send external arrayBuffer: response => promise<arrayBuffer> = "arrayBuffer"
@get external byteLength: arrayBuffer => float = "byteLength"
let bytesFromString: string => arrayBuffer = %raw(`text => new TextEncoder().encode(text).buffer`)
let bytePrefix: (
  arrayBuffer,
  int,
) => byteView = %raw(`(buffer, limit) => new Uint8Array(buffer, 0, Math.min(buffer.byteLength, limit))`)
let asciiView: byteView => string = %raw(`bytes => String.fromCharCode(...bytes)`)

/** Bounded declaration sniff, not browser encoding detection. Attribute parsing
    stays in this binding island alongside byte views and TextDecoder. */
let declaredCharset: (option<string>, string) => string = %raw(`(header, prefix) => {
  const charset = value => /(?:^|;)\s*charset\s*=\s*("[^"]*"|'[^']*'|[^;\s]+)/i.exec(value)?.[1];
  const normalize = label => {
    label = label.trim();
    if ((label.startsWith('"') && label.endsWith('"')) || (label.startsWith("'") && label.endsWith("'"))) label = label.slice(1, -1);
    return label.trim();
  };
  const fromHeader = charset(header ?? '');
  if (fromHeader !== undefined) return normalize(fromHeader);
  for (const tag of prefix.matchAll(/<meta\b[^>]*>/gi)) {
    const attrs = Object.create(null);
    for (const attr of tag[0].slice(5, -1).matchAll(/([^\s=/>]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/g)) {
      const key = attr[1].toLowerCase();
      if (!(key in attrs)) attrs[key] = attr[2] ?? attr[3] ?? attr[4] ?? '';
    }
    if ('charset' in attrs) return normalize(attrs.charset);
    if ((attrs['http-equiv'] ?? '').toLowerCase() === 'content-type') {
      const label = charset(attrs.content ?? '');
      if (label !== undefined) return normalize(label);
    }
  }
  return 'utf-8';
}`)

/** Unsupported labels fall directly back to UTF-8, never to a conflicting meta. */
let decodeBytes: (arrayBuffer, string) => string = %raw(`(buffer, label) => {
  let decoder;
  try { decoder = new TextDecoder(label); } catch (_) { decoder = new TextDecoder('utf-8'); }
  return decoder.decode(buffer);
}`)
let decodeHtml = (buffer, contentType) =>
  decodeBytes(buffer, declaredCharset(contentType, asciiView(bytePrefix(buffer, 1024))))

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
