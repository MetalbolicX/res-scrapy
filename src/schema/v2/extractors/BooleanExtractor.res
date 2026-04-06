/** Extract and evaluate a boolean from an HTML element (or its absence).
  *
  * Modes:
  *   Mapping (default) — compare trimmed text against trueValues / falseValues
  *   Presence          — element existence is the signal; call `extractPresence`
  *   AttributeCheck    — attribute presence/value signals truth
  */
open FieldTypes

let defaultTrueValues = ["true", "yes", "1", "on", "in stock"]
let defaultFalseValues = ["false", "no", "0", "off", "out of stock"]

let matchesAny: (string, array<string>) => bool = (s, arr) => {
  let lower = StringUtils.toLower(s)
  arr->Array.some(v => StringUtils.toLower(v) === lower)
}

/** Mapping mode: look up text in trueValues / falseValues. */
let extractMapping: (NodeHtmlParserBinding.htmlElement, option<booleanOptions>) => option<bool> = (
  el,
  opts,
) => {
  let text = StringUtils.trimStr(el.textContent)
  let trueVals = switch opts {
  | Some(o) =>
    switch o.trueValues {
    | Some(tv) if Array.length(tv) > 0 => tv
    | _ => defaultTrueValues
    }
  | None => defaultTrueValues
  }
  let falseVals = switch opts {
  | Some(o) =>
    switch o.falseValues {
    | Some(fv) if Array.length(fv) > 0 => fv
    | _ => defaultFalseValues
    }
  | None => defaultFalseValues
  }
  if matchesAny(text, trueVals) {
    Some(true)
  } else if matchesAny(text, falseVals) {
    Some(false)
  } else {
    // Unknown value — return onUnknown or None
    switch opts {
    | Some(o) =>
      switch o.onUnknown {
      | Some(b) => Some(b)
      | None => None
      }
    | None => None
    }
  }
}

/** Presence mode: element was found → true. Used by RowExtractor when element absent → false. */
let extractPresence: bool => bool = found => found

/** AttributeCheck mode: check that a named attribute is present (and non-empty). */
let extractAttributeCheck: (
  NodeHtmlParserBinding.htmlElement,
  option<booleanOptions>,
) => option<bool> = (el, opts) => {
  let attrName = switch opts {
  | Some({attribute: a}) => a
  | _ => "data-value"
  }
  switch NodeHtmlParserBinding.getAttribute(el, attrName)->Nullable.toOption {
  | Some(v) if v !== "" => Some(true)
  | Some(_) => Some(false)
  | None => Some(false)
  }
}

/** Dispatch to the right mode. Returns `option<bool>`. */
let extract: (NodeHtmlParserBinding.htmlElement, option<booleanOptions>) => option<bool> = (
  el,
  opts,
) => {
  let mode = switch opts {
  | Some(o) =>
    switch o.mode {
    | Some(m) => m
    | None => Mapping
    }
  | None => Mapping
  }
  switch mode {
  | Mapping => extractMapping(el, opts)
  | Presence => Some(extractPresence(true))
  | AttributeCheck => extractAttributeCheck(el, opts)
  }
}
