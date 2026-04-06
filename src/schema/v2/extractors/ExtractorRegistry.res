/** Central dispatch: maps a fieldType variant → concrete extractor → JSON.t.
  * All extractors return `option<X>`; None becomes `JSON.Encode.null`.
  * `presence` is used by RowExtractor for boolean Presence mode when the
  * element is absent within a row context.
  *
  * Two entry points:
  *   extractValue      — single htmlElement; used by all scalar field types.
  *   extractValueList  — full element array; used by Count (and future List).
  */
open FieldTypes

let extractValue: (NodeHtmlParserBinding.htmlElement, fieldType) => JSON.t = (el, ft) => {
  switch ft {
  | Text(opts) =>
    switch TextExtractor.extract(el, opts) {
    | Some(s) => JSON.Encode.string(s)
    | None => JSON.Encode.null
    }
  | Html(opts) =>
    switch HtmlExtractor.extract(el, opts) {
    | Some(s) => JSON.Encode.string(s)
    | None => JSON.Encode.null
    }
  | Attribute(cfg) =>
    switch AttributeExtractor.extract(el, cfg) {
    | Some(s) => JSON.Encode.string(s)
    | None => JSON.Encode.null
    }
  | Number(opts) =>
    switch NumberExtractor.extract(el, opts) {
    | Some(n) => JSON.Encode.float(n)
    | None => JSON.Encode.null
    }
  | Boolean(opts) =>
    switch BooleanExtractor.extract(el, opts) {
    | Some(b) => JSON.Encode.bool(b)
    | None => JSON.Encode.null
    }
  | Url(opts) =>
    switch UrlExtractor.extract(el, opts) {
    | Some(s) => JSON.Encode.string(s)
    | None => JSON.Encode.null
    }
  | Json(opts) =>
    switch JsonExtractor.extract(el, opts) {
    | Some(json) => json
    | None => JSON.Encode.null
    }
  | DateTime(opts) =>
    switch DateTimeExtractor.extract(el, opts) {
    | Some(s) => JSON.Encode.string(s)
    | None => JSON.Encode.null
    }
  | Count(_) =>
    // Count requires the full element array; callers must use extractValueList.
    // If somehow routed here, return 1 (the element itself was found).
    JSON.Encode.int(1)
  | List(_) =>
    // List requires the full element array; callers must use extractValueList.
    JSON.Encode.null
  }
}

/** Multi-element dispatch for field types that operate on the whole match set.
  * Currently handles Count. Scalar types fall back to extractValue on the
  * first element (or null when the list is empty). */
let extractValueList: (array<NodeHtmlParserBinding.htmlElement>, fieldType) => JSON.t = (
  els,
  ft,
) => {
  switch ft {
  | Count(opts) =>
    switch CountExtractor.extract(els, opts) {
    | Some(n) => JSON.Encode.int(n)
    | None => JSON.Encode.null
    }
  | List(opts) =>
    switch ListExtractor.extract(els, opts) {
    | Some(json) => json
    | None => JSON.Encode.null
    }
  | _ =>
    // Scalar fallback: delegate to the single-element path on the first match.
    switch Array.get(els, 0) {
    | Some(el) => extractValue(el, ft)
    | None => JSON.Encode.null
    }
  }
}

/** Absence-aware variant for row contexts.
  * When the element was not found (`found = false`) and the field is
  * `Boolean(Presence)`, returns `false` instead of null. */
let extractValueOrAbsent: (option<NodeHtmlParserBinding.htmlElement>, fieldType) => JSON.t = (
  maybeEl,
  ft,
) => {
  switch maybeEl {
  | Some(el) => extractValue(el, ft)
  | None =>
    switch ft {
    | Boolean(opts)
      if switch opts {
      | Some({mode: Presence}) => true
      | _ => false
      } =>
      JSON.Encode.bool(false)
    | _ => JSON.Encode.null
    }
  }
}
