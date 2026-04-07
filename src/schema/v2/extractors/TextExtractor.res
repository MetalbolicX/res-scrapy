/** Extract and transform text content from an HTML element. */
open FieldTypes

let extract: (NodeHtmlParserBinding.htmlElement, option<textOptions>) => option<string> = (
  el,
  opts,
) => {
  // If join is set the caller may pass multiple elements; for single element join is ignored.
  let base = el.textContent

  let s = ref(base)

  switch opts {
  | None =>
    // Default: trim
    s := StringUtils.trimStr(s.contents)
  | Some(o) => {
      if o.normalizeWhitespace == Some(true) {
        s := StringUtils.normalizeWhitespace(s.contents)
      } else if o.trim != Some(false) {
        // trim is on by default unless explicitly disabled
        s := StringUtils.trimStr(s.contents)
      }

      switch o.pattern {
      | Some(pat) =>
        switch StringUtils.extractPattern(s.contents, pat) {
        | Some(extracted) => s := extracted
        | None => s := ""
        }
      | None => ()
      }

      if o.lowercase == Some(true) {
        s := StringUtils.toLower(s.contents)
      }
      if o.uppercase == Some(true) {
        s := StringUtils.toUpper(s.contents)
      }
    }
  }

  if s.contents === "" {
    None
  } else {
    Some(s.contents)
  }
}

/** Join text from multiple elements, used when a field targets a list. */
let extractJoined: (
  array<NodeHtmlParserBinding.htmlElement>,
  string,
  option<textOptions>,
) => option<string> = (els, sep, opts) => {
  let parts = els->Array.filterMap(el => extract(el, opts))
  if Array.length(parts) === 0 {
    None
  } else {
    Some(Array.join(parts, sep))
  }
}
