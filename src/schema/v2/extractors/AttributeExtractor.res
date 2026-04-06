/** Extract one or more attributes from an element according to attributeConfig. */

open FieldTypes

let getAttr: (NodeHtmlParserBinding.htmlElement, string) => option<string> = (el, name) => {
  switch NodeHtmlParserBinding.getAttribute(el, name)->Nullable.toOption {
  | Some(v) when v !== "" => Some(v)
  | _ => None
  }
}

let getAttrRaw: (NodeHtmlParserBinding.htmlElement, string) => option<string> = (el, name) => {
  NodeHtmlParserBinding.getAttribute(el, name)->Nullable.toOption
}

let extract: (NodeHtmlParserBinding.htmlElement, attributeConfig) => option<string> = (el, cfg) => {
  switch cfg.mode {
  | First =>
    switch Array.get(cfg.names, 0) {
    | None => None
    | Some(name) => getAttrRaw(el, name)
    }
  | FirstNonEmpty =>
    cfg.names->Array.reduce(None, (acc, name) => {
      switch acc {
      | Some(_) => acc
      | None => getAttr(el, name)
      }
    })
  | All =>
    let sep = cfg.joinSep->Option.getOr(" ")
    let vals = cfg.names->Array.filterMap(name => getAttrRaw(el, name))
    if Array.length(vals) === 0 { None }
    else { Some(Array.join(vals, sep)) }
  | Join =>
    let sep = cfg.joinSep->Option.getOr(" ")
    let vals = cfg.names->Array.filterMap(name => getAttrRaw(el, name))
    if Array.length(vals) === 0 { None }
    else { Some(Array.join(vals, sep)) }
  }
}
