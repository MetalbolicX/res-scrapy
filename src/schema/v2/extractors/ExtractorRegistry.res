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

let columnTypeToFieldType: columnFieldType => fieldType = columnType =>
  switch columnType {
  | ColumnText(opts) => Text(opts)
  | ColumnAttribute(cfg) => Attribute(cfg)
  | ColumnHtml(opts) => Html(opts)
  | ColumnNumber(opts) => Number(opts)
  | ColumnBoolean(opts) => Boolean(opts)
  | ColumnUrl(opts) => Url(opts)
  | ColumnJson(opts) => Json(opts)
  | ColumnDateTime(opts) => DateTime(opts)
  | ColumnList(opts) => List(opts)
  }

let rec extractValue: (
  NodeHtmlParserBinding.htmlElement,
  fieldType,
  option<schemaDefaults>,
  bool,
) => result<JSON.t, schemaError> = (el, ft, defaults, ignoreErrors) => {
  switch DefaultsMerger.resolveDefaults(defaults, ft) {
  | Text(opts) => TextScalar.run(el, opts)
  | Html(opts) => HtmlScalar.run(el, opts)
  | Attribute(cfg) => AttributeScalar.run(el, cfg)
  | Number(opts) => NumberScalar.run(el, opts)
  | Boolean(opts) =>
    switch BooleanExtractor.extract(el, opts) {
    | Ok(Some(b)) => Ok(JSON.Encode.bool(b))
    | Ok(None) => Ok(JSON.Encode.null)
    | Error(e) => Error(e)
    }
  | Url(opts) => UrlScalar.run(el, opts)
  | Json(opts) => JsonScalar.run(el, opts)
  | DateTime(opts) => DateTimeScalar.run(el, opts)
  | Count(_) =>
    // Count requires the full element array; callers must use extractValueList.
    // If somehow routed here, return 1 (the element itself was found).
    Ok(JSON.Encode.int(1))
  | List(_) =>
    // List requires the full element array; callers must use extractValueList.
    Ok(JSON.Encode.null)
  | Table(tableOpts) => {
      let resolvedColumns = tableOpts.columns->Array.map(col => {
        let resolvedFieldType = switch col.columnType {
        | ColumnList(opts) => List(opts)
        | _ => DefaultsMerger.resolveDefaults(defaults, columnTypeToFieldType(col.columnType))
        }
        let nestedDefaults = switch resolvedFieldType {
        | Table(_) => defaults
        | _ => None
        }
        (col, resolvedFieldType, nestedDefaults)
      })

      let rows: array<NodeHtmlParserBinding.htmlElement> = switch tableOpts.rowSelector {
      | Some(sel) => el->NodeHtmlParserBinding.querySelectorAll(sel)
      | None => {
          let tbodyRows = el->NodeHtmlParserBinding.querySelectorAll("tbody tr")
          if Array.length(tbodyRows) > 0 {
            tbodyRows
          } else {
            let allRows = el->NodeHtmlParserBinding.querySelectorAll("tr")
            if Array.length(allRows) <= 1 {
              []
            } else {
              Array.slice(allRows, ~start=1, ~end=Array.length(allRows))
            }
          }
        }
      }

      let rowsResult: result<array<JSON.t>, schemaError> = rows->Array.reduce(Ok([]), (acc, rowEl) => {
        switch acc {
        | Error(e) => Error(e)
        | Ok(outputRows) => {
            let pairsResult: result<array<(string, JSON.t)>, schemaError> =
              resolvedColumns->Array.reduce(Ok([]), (pAcc, (col, resolvedFieldType, nestedDefaults)) => {
                switch pAcc {
                | Error(e) => Error(e)
                | Ok(pairs) => {
                    let value: result<JSON.t, schemaError> = switch resolvedFieldType {
                    | List(opts) => {
                        let allEls = rowEl->NodeHtmlParserBinding.querySelectorAll(col.selector)
                        switch ListExtractor.extract(allEls, opts) {
                        | Some(json) => Ok(json)
                        | None => Ok(JSON.Encode.null)
                        }
                      }
                    | _ => {
                        switch rowEl
                        ->NodeHtmlParserBinding.querySelector(col.selector)
                        ->Nullable.toOption {
                        | Some(colEl) =>
                          extractValue(colEl, resolvedFieldType, nestedDefaults, ignoreErrors)
                        | None =>
                          if col.required && ignoreErrors == false {
                            Error(RequiredFieldMissing({fieldName: col.name, selector: col.selector}))
                          } else {
                            Ok(
                              switch col.default {
                              | Some(d) => d
                              | None => JSON.Encode.null
                              },
                            )
                          }
                        }
                      }
                    }
                    switch value {
                    | Error(e) =>
                      if ignoreErrors {
                        let fallback = switch col.default {
                        | Some(d) => d
                        | None => JSON.Encode.null
                        }
                        pairs->Array.push((col.name, fallback))
                        Ok(pairs)
                      } else {
                        Error(e)
                      }
                    | Ok(v) => {
                        pairs->Array.push((col.name, v))
                        Ok(pairs)
                      }
                    }
                  }
                }
              })

            switch pairsResult {
            | Error(e) => Error(e)
            | Ok(pairs) => {
                outputRows->Array.push(JSON.Encode.object(Dict.fromArray(pairs)))
                Ok(outputRows)
              }
            }
          }
        }
      })

      switch rowsResult {
      | Error(e) => Error(e)
      | Ok(arr) => Ok(JSON.Encode.array(arr))
      }
    }
  }
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
    | Count(opts) =>
      switch CountExtractor.extract(els, opts) {
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
