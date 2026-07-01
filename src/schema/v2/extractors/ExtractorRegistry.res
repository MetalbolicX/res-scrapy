/** Central dispatch: maps a fieldType variant → concrete extractor → JSON.t.
  * Scalar extractors return `option<X>`; None becomes `JSON.Encode.null`.
  * `presence` is used by RowExtractor for boolean Presence mode when the
  * element is absent within a row context.
  *
  * Two entry points:
  *   extractValue      — single htmlElement; used by all scalar field types.
  *   extractValueList  — full element array; used by Count (and future List).
  */
open FieldTypes

module type ScalarExtractor = {
  type options
  type output

  let extract: (NodeHtmlParserBinding.htmlElement, option<options>) => option<output>
  let toJson: output => JSON.t
}

module MakeScalar = (Impl: ScalarExtractor) => {
  let run = (el, opts) => {
    switch Impl.extract(el, opts) {
    | Some(value) => Ok(Impl.toJson(value))
    | None => Ok(JSON.Encode.null)
    }
  }
}

module TextScalar = MakeScalar({
  type options = textOptions
  type output = string

  let extract = TextExtractor.extract
  let toJson = JSON.Encode.string
})

module HtmlScalar = MakeScalar({
  type options = htmlOptions
  type output = string

  let extract = HtmlExtractor.extract
  let toJson = JSON.Encode.string
})

module NumberScalar = MakeScalar({
  type options = numberOptions
  type output = float

  let extract = NumberExtractor.extract
  let toJson = JSON.Encode.float
})

module AttributeScalar = {
  let run = (el, cfg) => {
    switch AttributeExtractor.extract(el, cfg) {
    | Some(value) => Ok(JSON.Encode.string(value))
    | None => Ok(JSON.Encode.null)
    }
  }
}

module UrlScalar = MakeScalar({
  type options = urlOptions
  type output = string

  let extract = UrlExtractor.extract
  let toJson = JSON.Encode.string
})

module JsonScalar = {
  let run = (el, opts) => {
    switch JsonExtractor.extract(el, opts) {
    | Some(value) => Ok(value)
    | None => Ok(JSON.Encode.null)
    }
  }
}

module DateTimeScalar = MakeScalar({
  type options = dateOptions
  type output = string

  let extract = DateTimeExtractor.extract
  let toJson = JSON.Encode.string
})

let rec extractValue: (
  NodeHtmlParserBinding.htmlElement,
  fieldType,
  option<schemaDefaults>,
  bool,
) => result<JSON.t, schemaError> = (el, ft, defaults, ignoreErrors) => {
  let resolved = DefaultsMerger.resolveDefaults(defaults, ft)
  let extractVisitor: FieldTypeVisitor.fieldTypeVisitor<result<JSON.t, schemaError>> = {
    text: opts => TextScalar.run(el, opts),
    html: opts => HtmlScalar.run(el, opts),
    attribute: cfg => AttributeScalar.run(el, cfg),
    number: opts => NumberScalar.run(el, opts),
    boolean: opts =>
      switch BooleanExtractor.extract(el, opts) {
      | Ok(Some(b)) => Ok(JSON.Encode.bool(b))
      | Ok(None) => Ok(JSON.Encode.null)
      | Error(e) => Error(e)
      },
    url: opts => UrlScalar.run(el, opts),
    json: opts => JsonScalar.run(el, opts),
    datetime: opts => DateTimeScalar.run(el, opts),
    count: _ =>
      // Count requires the full element array; callers must use extractValueList.
      // If somehow routed here, return 1 (the element itself was found).
      Ok(JSON.Encode.int(1)),
    list: _ =>
      // List requires the full element array; callers must use extractValueList.
      Ok(JSON.Encode.null),
    table: tableOpts => TableFieldExtractor.extract(el, tableOpts, defaults, ignoreErrors, extractValue),
  }
  FieldTypeVisitor.visitFieldType(extractVisitor, resolved)
}

/** Multi-element dispatch for field types that operate on the whole match set.
  * Currently handles Count. Scalar types fall back to extractValue on the
  * first element (or null when the list is empty). */
let extractValueList: (
  array<NodeHtmlParserBinding.htmlElement>,
  fieldType,
  option<schemaDefaults>,
  bool,
  bool,
  string,
  string,
) => result<JSON.t, schemaError> = (els, ft, defaults, ignoreErrors, required, fieldName, selector) => {
  if Array.length(els) == 0 && required && ignoreErrors == false {
    Error(RequiredFieldMissing({fieldName, selector}))
  } else {
    switch DefaultsMerger.resolveDefaults(defaults, ft) {
    | Count(_) =>
      switch CountExtractor.extract(els) {
      | Some(n) => Ok(JSON.Encode.int(n))
      | None => Ok(JSON.Encode.null)
      }
    | List(opts) =>
      switch ListExtractor.extract(els, opts) {
      | Some(json) => Ok(json)
      | None => Ok(JSON.Encode.null)
      }
    | _ =>
      // Scalar fallback: delegate to the single-element path on the first match.
      switch els[0] {
      | Some(el) => extractValue(el, ft, defaults, ignoreErrors)
      | None => Ok(JSON.Encode.null)
      }
    }
  }
}

/** Absence-aware variant for row contexts.
  * When the element was not found (`found = false`) and the field is
  * `Boolean(Presence)`, returns `false` instead of null. */
let extractValueOrAbsent: (
  option<NodeHtmlParserBinding.htmlElement>,
  fieldType,
  option<JSON.t>,
  bool,
  string,
  string,
  option<schemaDefaults>,
  bool,
) => result<JSON.t, schemaError> = (
  maybeEl,
  ft,
  defaultValue,
  required,
  fieldName,
  selector,
  defaults,
  ignoreErrors,
) => {
  switch maybeEl {
  | Some(el) => extractValue(el, ft, defaults, ignoreErrors)
  | None =>
    switch ft {
    | Boolean(opts)
      if switch opts {
      | Some({mode: Presence}) => true
      | _ => false
      } =>
      Ok(JSON.Encode.bool(false))
    | _ =>
      if required && ignoreErrors == false {
        Error(RequiredFieldMissing({fieldName, selector}))
      } else {
        Ok(switch defaultValue {
        | Some(d) => d
        | None => JSON.Encode.null
        })
      }
    }
  }
}
