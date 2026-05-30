/** List extractor — collects values from an array of HTML elements.
  *
  * itemType controls how each element's value is extracted:
  *   ListText             → textContent (trimmed)
  *   ListHtml             → innerHTML
  *   ListAttribute(name)  → named attribute value
  *   ListUrl              → href/src attribute (same logic as UrlExtractor)
  *
  * Post-processing (in order): filter → unique → limit → join/array output.
  */
open FieldTypes

module Iter = NodeJsBinding.Iter

// @get external textContent: NodeHtmlParserBinding.htmlElement => string = "textContent"
// @get external innerHTML: NodeHtmlParserBinding.htmlElement => string = "innerHTML"

let extractItemValue: (NodeHtmlParserBinding.htmlElement, listItemType) => option<string> = (
  el,
  itemType,
) => {
  switch itemType {
  | ListText => {
      let t = String.trim(el.textContent)
      if String.length(t) === 0 {
        None
      } else {
        Some(t)
      }
    }
  | ListHtml => {
      let h = el.innerHTML
      if String.length(h) === 0 {
        None
      } else {
        Some(h)
      }
    }
  | ListAttribute(name) =>
    switch NodeHtmlParserBinding.getAttribute(el, name)->Nullable.toOption {
    | None => None
    | Some(v) =>
      let t = String.trim(v)
      if String.length(t) === 0 {
        None
      } else {
        Some(t)
      }
    }
  | ListUrl =>
    // Reuse UrlExtractor with no options (extracts href/src, validates)
    UrlExtractor.extract(el, None)
  }
}

let extract: (array<NodeHtmlParserBinding.htmlElement>, listOptions) => option<JSON.t> = (
  els,
  opts,
) => {
  // 1. Extract raw values, dropping None
  let values: array<string> = els->Iter.values->Iter.reduce((acc, el) => {
    switch extractItemValue(el, opts.itemType) {
    | None => acc
    | Some(v) => {
        acc->Array.push(v)
        acc
      }
    }
  }, [])

  // 2. Filter by regex if provided
  let filtered = switch opts.filter {
  | None => values
  | Some(pat) => values->Iter.values->Iter.filter(v => StringUtils.matchesPattern(v, pat))->Iter.toArray
  }

  // 3. Deduplicate (preserve first-occurrence order)
  let deduped = switch opts.unique {
  | Some(true) => {
      let seen: Dict.t<bool> = Dict.make()
      filtered->Iter.values->Iter.filter(v => {
        if Dict.has(seen, v) {
          false
        } else {
          Dict.set(seen, v, true)
          true
        }
      })->Iter.toArray
    }
  | _ => filtered
  }

  // 4. Apply limit
  let limited = switch opts.limit {
  | None => deduped
  | Some(n) =>
    if n < Array.length(deduped) {
      Array.slice(deduped, ~start=0, ~end=n)
    } else {
      deduped
    }
  }

  // 5. Join or return array
  switch opts.join {
  | Some(sep) => Some(JSON.Encode.string(Array.join(limited, sep)))
  | None => Some(JSON.Encode.array(limited->Iter.values->Iter.map(JSON.Encode.string)->Iter.toArray))
  }
}
