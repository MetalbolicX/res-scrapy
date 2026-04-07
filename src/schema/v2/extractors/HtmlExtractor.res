/** Extract innerHTML or outerHTML from an element. */
open FieldTypes

let stripTagBlocks: (string, string) => string = %raw(`
  function(html, tagName) {
    var re = new RegExp('<' + tagName + '\\b[^>]*>[\\s\\S]*?<\\/' + tagName + '>', 'gi');
    return html.replace(re, '');
  }
`)

let extract: (NodeHtmlParserBinding.htmlElement, option<htmlOptions>) => option<string> = (
  el,
  opts,
) => {
  let html = switch opts {
  | Some({mode: Outer}) => el.outerHTML
  | _ => el.innerHTML
  }
  let stripped = switch opts {
  | Some(o) => {
      let acc = ref(html)
      if o.stripScripts == Some(true) {
        acc := stripTagBlocks(acc.contents, "script")
      }
      if o.stripStyles == Some(true) {
        acc := stripTagBlocks(acc.contents, "style")
      }
      acc.contents
    }
  | None => html
  }
  let trimmed = StringUtils.trimStr(stripped)
  if trimmed === "" {
    None
  } else {
    Some(trimmed)
  }
}
