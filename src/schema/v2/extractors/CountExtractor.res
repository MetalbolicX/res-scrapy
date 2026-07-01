/** Count the number of elements matching a selector.
  *
  * Takes the full element array (from querySelectorAll) rather than a
  * single element. No configuration options currently.
  */
let extract: array<NodeHtmlParserBinding.htmlElement> => option<int> = els => Some(
  Array.length(els),
)
