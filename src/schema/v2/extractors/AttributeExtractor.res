/** Extract one or more attributes from an element according to attributeConfig. */
open FieldTypes

module Iter = NodeJsBinding.Iter

let getAttr: (NodeHtmlParserBinding.htmlElement, string) => option<string> = (el, name) =>
  switch NodeHtmlParserBinding.getAttribute(el, name)->Nullable.toOption {
  | Some(v) if v !== "" => Some(v)
  | _ => None
  }

let getAttrRaw: (NodeHtmlParserBinding.htmlElement, string) => option<string> = (el, name) =>
  NodeHtmlParserBinding.getAttribute(el, name)->Nullable.toOption

let extract: (NodeHtmlParserBinding.htmlElement, attributeConfig) => option<string> = (el, cfg) => {
  switch cfg.mode {
  | First =>
    switch cfg.names[0] {
    | None => None
    | Some(name) => getAttrRaw(el, name)
    }
  | FirstNonEmpty =>
    cfg.names->Iter.values->Iter.reduce((acc, name) => {
      switch acc {
      | Some(_) => acc
      | None => getAttr(el, name)
      }
    }, None)
  | All | Join =>
    let sep = cfg.joinSep->Option.getOr(" ")
    let vals = cfg.names->Iter.values->Iter.reduce((acc, name) => {
      switch getAttrRaw(el, name) {
      | None => acc
      | Some(v) => {
          acc->Array.push(v)
          acc
        }
      }
    }, [])
    if Array.length(vals) === 0 {
      None
    } else {
      Some(Array.join(vals, sep))
    }
  }
}
