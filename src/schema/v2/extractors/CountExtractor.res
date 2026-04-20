/** Count the number of elements matching a selector.
  *
  * Takes the full element array (from querySelectorAll) rather than a
  * single element. min/max are validation hints — when the count falls
  * outside the range, the raw count is still returned (no error thrown).
  */
open FieldTypes

let extract: (array<NodeHtmlParserBinding.htmlElement>, option<countOptions>) => option<int> = (
  els,
  _opts,
) => Some(Array.length(els))
