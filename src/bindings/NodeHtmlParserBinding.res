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

/** Returns all descendants matching `selector` as an array; empty array when none match.
  *
  * Fast path for plain `.class`, `#id`, and `tag` selectors: walks the tree
  * once, pre-order, applying exactly the test the css-select adapter applies
  * (isTag = nodeType 1, descendants only — like css-select, the context element
  * itself is never tested — class tokens via `(?:^|\s)` regex
  * over the raw `class` attribute, `id` by exact equality, tag names compared
  * case-sensitively against the lower-cased `rawTagName` because node-html-parser
  * queries with `xmlMode: true`). This matters because node-html-parser 9.x
  * routes every query through a vendored `findAll` that copies the accumulator
  * at every visited node (`result = result.concat(findAll(test, childs))`),
  * which is quadratic in the number of matching siblings and dominated query
  * time on large pages. Any other selector falls back to the library unchanged. */
@send external querySelectorAllLib: (htmlElement, string) => array<htmlElement> = "querySelectorAll"

let fastSelectAll: (
  htmlElement,
  string,
) => Nullable.t<array<htmlElement>> = %raw(`(root, selector) => {
  const m = /^(?:\.([-\w]+)|#([-\w]+)|([a-zA-Z][a-zA-Z0-9-]*))$/.exec(selector);
  if (m === null || root === null || root === undefined) return null;
  const isClass = m[1] !== undefined;
  const isId = m[2] !== undefined;
  const token = isClass ? m[1] : isId ? m[2] : selector;
  const classRe = isClass ? new RegExp("(?:^|\\s)" + token + "(?:$|\\s)") : null;
  const matches = (elem) => {
    if (isClass) {
      const attr = elem.getAttribute("class");
      return attr != null && attr.length >= token.length && classRe.test(attr);
    }
    if (isId) return elem.getAttribute("id") === token;
    return (elem.rawTagName || "").toLowerCase() === token;
  };
  const out = [];
  const stack = [];
  const top = root.childNodes;
  if (top) for (let i = top.length - 1; i >= 0; i--) stack.push(top[i]);
  while (stack.length > 0) {
    const node = stack.pop();
    if (node.nodeType === 1 && matches(node)) out.push(node);
    const kids = node.childNodes;
    if (kids) for (let i = kids.length - 1; i >= 0; i--) stack.push(kids[i]);
  }
  return out;
}`)

let querySelectorAll: (htmlElement, string) => array<htmlElement> = (root, selector) =>
  switch fastSelectAll(root, selector)->Nullable.toOption {
  | Some(result) => result
  | None => querySelectorAllLib(root, selector)
  }

/** Returns the first descendant matching `selector`, or `null` when none match. */
@send external querySelector: (htmlElement, string) => Nullable.t<htmlElement> = "querySelector"

/** Returns the value of a named attribute, or `null` when the attribute does not exist. */
@send external getAttribute: (htmlElement, string) => Nullable.t<string> = "getAttribute"
