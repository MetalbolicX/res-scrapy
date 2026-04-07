/** Extract innerHTML or outerHTML from an element. */
open FieldTypes

let stripTagBlocks: (string, string) => string = (html, tagName) => {
  try {
    // Construct the pattern string: <tag\b[^>]*>[\s\S]*?<\/tag>
    let pattern = "<" ++ tagName ++ "\\b[^>]*>[\\s\\S]*?<\/" ++ tagName ++ ">"

    // Create the RegExp with "gi" flags
    let re = RegExp.fromString(pattern, ~flags="gi")

    // Use the built-in String.replaceRegExp
    html->String.replaceRegExp(re, "")
  } catch {
  | _ => html // If the tagName creates an invalid Regex, return the original string
  }
}

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
