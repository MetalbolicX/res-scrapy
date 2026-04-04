/**
  * A parsed HTML element node returned by `node-html-parser`.
  *
  * - `textContent` — the combined text of the element and all its descendants.
  * - `outerHTML`   — serialised HTML including the element's own opening/closing tags.
  * - `innerHTML`   — serialised HTML of the element's *children only* (no outer tags).
  * - `tagName`     — upper-cased tag name (e.g. `"DIV"`, `"A"`).
 */
type htmlElement = {
  textContent: string,
  outerHTML: string,
  innerHTML: string,
  tagName: string,
}

/** Parses an HTML string into a root `htmlElement` document node. */
@module("node-html-parser") external parse: string => htmlElement = "parse"

/** Returns all descendants matching `selector` as an array; empty array when none match. */
@send external querySelectorAll: (htmlElement, string) => array<htmlElement> = "querySelectorAll"

/** Returns the first descendant matching `selector`, or `null` when none match. */
@send external querySelector: (htmlElement, string) => Nullable.t<htmlElement> = "querySelector"

/** Returns the value of a named attribute, or `null` when the attribute does not exist. */
@send external getAttribute: (htmlElement, string) => Nullable.t<string> = "getAttribute"
