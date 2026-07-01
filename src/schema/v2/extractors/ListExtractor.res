/** List extractor — collects values from an array of HTML elements.
  *
  * itemType controls how each element's value is extracted:
  *   ListText             → delegates to TextExtractor (trim+filter-empty)
  *   ListHtml             → reads innerHTML directly (filter-empty only;
  *                          preserves raw whitespace so <li>  </li> is NOT
  *                          silently dropped — html may carry structural
  *                          whitespace that callers want)
  *   ListAttribute(name)  → delegates to AttributeExtractor (First mode);
  *                          list-level trim+filter-empty applied post-hoc
  *   ListUrl              → delegates to UrlExtractor (no extra options;
  *                          extractor handles URL validation/resolve)
  *
  * This module no longer duplicates per-element extraction logic — each
  * branch is a thin wrapper over the canonical named extractor, with the
  * list-level normalisation (trim+filter-empty) applied as a post-step
  * when the named extractor does not already cover it.
  *
  * Post-processing (in order): filter → unique → limit → join/array output.
  */
open FieldTypes

module Iter = NodeJsBinding.Iter

/* listTrim applies the trim+filter-empty normalisation that list semantics
   require. TextExtractor already trims and filters empty, and UrlExtractor
   handles URL-level filtering; AttributeExtractor's First mode returns raw
   values, so we apply listTrim there. */
let listTrim = (s: string): option<string> => {
  let t = String.trim(s)
  if String.length(t) === 0 {
    None
  } else {
    Some(t)
  }
}

let extractItemValue: (NodeHtmlParserBinding.htmlElement, listItemType) => option<string> = (
  el,
  itemType,
) => {
  switch itemType {
  | ListText =>
    // TextExtractor already trims base textContent and returns None on empty.
    TextExtractor.extract(el, None)
  | ListHtml => {
      let h = el.innerHTML

      // Preserve existing semantics: filter empty innerHTML only (no trim).
      if String.length(h) === 0 {
        None
      } else {
        Some(h)
      }
    }
  | ListAttribute(name) =>
    AttributeExtractor.extract(el, {names: [name], mode: First})->Option.flatMap(listTrim)
  | ListUrl =>
    // UrlExtractor with no options: extracts href/src, validates.
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
  | Some(pat) =>
    values->Iter.values->Iter.filter(v => StringUtils.matchesPattern(v, pat))->Iter.toArray
  }

  // 3. Deduplicate (preserve first-occurrence order)
  let deduped = switch opts.unique {
  | Some(true) => {
      let seen: Dict.t<bool> = Dict.make()
      filtered
      ->Iter.values
      ->Iter.filter(v => {
        if Dict.has(seen, v) {
          false
        } else {
          Dict.set(seen, v, true)
          true
        }
      })
      ->Iter.toArray
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
  | None =>
    Some(JSON.Encode.array(limited->Iter.values->Iter.map(JSON.Encode.string)->Iter.toArray))
  }
}
