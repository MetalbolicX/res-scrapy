/** Count the number of elements matching a selector.
  *
  * Takes the full element array (from querySelectorAll) rather than a
  * single element.  min/max are informational — a count outside that range
  * is still returned as-is rather than being treated as an error.
  */

open FieldTypes

let extract: (array<NodeHtmlParserBinding.htmlElement>, option<countOptions>) => option<int> = (
  els,
  _opts,
) => {
  // min/max are validation hints only; we always return the real count.
  Some(Array.length(els))
}
