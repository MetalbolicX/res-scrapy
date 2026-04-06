/** Central dispatch: maps a fieldType variant → concrete extractor → JSON.t.
  * All extractors return `option<X>`; None becomes `JSON.Encode.null`.
  * `presence` is used by RowExtractor for boolean Presence mode when the
  * element is absent within a row context.
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
