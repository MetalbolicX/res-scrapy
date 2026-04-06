/** Extract innerHTML or outerHTML from an element. */
open FieldTypes

let extract: (NodeHtmlParserBinding.htmlElement, option<htmlOptions>) => option<string> = (
  el,
  opts,
) => {
  let html = switch opts {
  | Some({mode: Outer}) => el.outerHTML
  | _ => el.innerHTML
  }
  let trimmed = StringUtils.trimStr(html)
  if trimmed === "" {
    None
  } else {
    Some(trimmed)
  }
}
