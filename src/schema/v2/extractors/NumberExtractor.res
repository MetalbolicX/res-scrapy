/** Extract and parse a numeric value from an HTML element.
  * Returns a JSON-compatible float boxed as `option<float>`.
  * The raw text source is always `textContent`.
  */

open FieldTypes

let extract: (NodeHtmlParserBinding.htmlElement, option<numberOptions>) => option<float> = (el, opts) => {
  let raw = StringUtils.trimStr(el.textContent)
  NumberUtils.parseWithOptions(raw, opts)
}
