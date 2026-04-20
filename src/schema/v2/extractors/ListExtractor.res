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

/** Compile and validate a user-provided regex filter.
  * Guardrails:
  *   - max length 200
  *   - reject lookarounds and backreferences
  *   - reject common catastrophic nested-quantifier forms
  */
let compileSafePattern: string => option<RegExp.t> = %raw(`
pattern => {
  if (!pattern || typeof pattern !== "string") return undefined;
  if (pattern.length > 200) return undefined;

  // Disallow backreferences: \1, \2, ...
  if (/\\[1-9][0-9]*/.test(pattern)) return undefined;

  // Disallow lookaheads/lookbehinds
  if (/\(\?[:=!<]/.test(pattern)) return undefined;

  // Disallow nested quantified groups (e.g. (a+)+, (a*)+, (a{1,3})*)
  if (/\([^)]*[+*?][^)]*\)\s*[+*?]/.test(pattern)) return undefined;
  if (/\([^)]*\{[^}]+\}[^)]*\)\s*[+*?]/.test(pattern)) return undefined;

  // Disallow wide quantified alternation groups (often expensive)
  if (/\((?:[^()]*\|){3,}[^()]*\)\s*[+*{]/.test(pattern)) return undefined;

  // Disallow very large explicit quantifiers
  if (/\{(?:\d{4,}|\d+,\d{4,}|\d{4,},)\}/.test(pattern)) return undefined;

  try {
    return new RegExp(pattern);
  } catch {
    return undefined;
  }
}
`)

let matchesCompiledPattern: (RegExp.t, string) => bool = %raw(`(re, str) => re.test(str)`)

let extract: (array<NodeHtmlParserBinding.htmlElement>, listOptions) => option<JSON.t> = (
  els,
  opts,
) => {
  // 1. Extract raw values, dropping None
  let values: array<string> =
    els
    ->Array.map(el => extractItemValue(el, opts.itemType))
    ->Array.filterMap(x => x)

  // 2. Filter by regex if provided
  let filtered = switch opts.filter {
  | None => values
  | Some(pat) =>
    switch compileSafePattern(pat) {
    | Some(re) => values->Array.filter(v => matchesCompiledPattern(re, v))
    | None => []
    }
  }

  // 3. Deduplicate (preserve first-occurrence order)
  let deduped = switch opts.unique {
  | Some(true) => {
      let seen: Dict.t<bool> = Dict.make()
      filtered->Array.filter(v => {
        if Dict.has(seen, v) {
          false
        } else {
          Dict.set(seen, v, true)
          true
        }
      })
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
  | None => Some(JSON.Encode.array(limited->Array.map(JSON.Encode.string)))
  }
}
