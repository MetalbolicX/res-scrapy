/** Node.js `node:url` module — URL parsing, resolution, and formatting. */
/** URL object returned by the URL constructor. */
type urlObj = {
  href: string,
  protocol: string,
  hostname: string,
  pathname: string,
  search: string,
  hash: string,
}

/** Parse and resolve a URL against an optional base URL.
  * `new URL(relative, base)` resolves relative URLs; `new URL(absolute)` parses an absolute URL. */
@new @module("node:url") external make: (string, option<string>) => urlObj = "URL"
