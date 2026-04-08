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

let pickOption = (current, fallback) =>
  switch current {
  | Some(value) => Some(value)
  | None => fallback
  }

let mergeTextOptions = (fieldOpts: option<textOptions>, defaultOpts: option<textOptions>) =>
  switch defaultOpts {
  | None => fieldOpts
  | Some(def) =>
    switch fieldOpts {
    | None => Some(def)
    | Some(opts) =>
      Some({
        trim: ?pickOption(opts.trim, def.trim),
        normalizeWhitespace: ?pickOption(opts.normalizeWhitespace, def.normalizeWhitespace),
        lowercase: ?pickOption(opts.lowercase, def.lowercase),
        uppercase: ?pickOption(opts.uppercase, def.uppercase),
        pattern: ?pickOption(opts.pattern, def.pattern),
        join: ?pickOption(opts.join, def.join),
      })
    }
  }

let mergeNumberOptions = (fieldOpts: option<numberOptions>, defaultOpts: option<numberOptions>) =>
  switch defaultOpts {
  | None => fieldOpts
  | Some(def) =>
    switch fieldOpts {
    | None => Some(def)
    | Some(opts) =>
      Some({
        stripNonNumeric: ?pickOption(opts.stripNonNumeric, def.stripNonNumeric),
        pattern: ?pickOption(opts.pattern, def.pattern),
        thousandsSeparator: ?pickOption(opts.thousandsSeparator, def.thousandsSeparator),
        decimalSeparator: ?pickOption(opts.decimalSeparator, def.decimalSeparator),
        precision: ?pickOption(opts.precision, def.precision),
        allowNegative: ?pickOption(opts.allowNegative, def.allowNegative),
        onError: ?pickOption(opts.onError, def.onError),
      })
    }
  }

let mergeBooleanOptions = (
  fieldOpts: option<booleanOptions>,
  defaultOpts: option<booleanOptions>,
) =>
  switch defaultOpts {
  | None => fieldOpts
  | Some(def) =>
    switch fieldOpts {
    | None => Some(def)
    | Some(opts) =>
      Some({
        mode: ?pickOption(opts.mode, def.mode),
        trueValues: ?pickOption(opts.trueValues, def.trueValues),
        falseValues: ?pickOption(opts.falseValues, def.falseValues),
        attribute: ?pickOption(opts.attribute, def.attribute),
        onUnknown: ?pickOption(opts.onUnknown, def.onUnknown),
      })
    }
  }

let mergeDateOptions = (fieldOpts: option<dateOptions>, defaultOpts: option<dateOptions>) =>
  switch defaultOpts {
  | None => fieldOpts
  | Some(def) =>
    switch fieldOpts {
    | None => Some(def)
    | Some(opts) =>
      Some({
        formats: ?pickOption(opts.formats, def.formats),
        timezone: ?pickOption(opts.timezone, def.timezone),
        output: ?pickOption(opts.output, def.output),
        strict: ?pickOption(opts.strict, def.strict),
        source: ?pickOption(opts.source, def.source),
        attribute: ?pickOption(opts.attribute, def.attribute),
      })
    }
  }

let mergeUrlOptions = (fieldOpts: option<urlOptions>, defaultOpts: option<urlOptions>) =>
  switch defaultOpts {
  | None => fieldOpts
  | Some(def) =>
    switch fieldOpts {
    | None => Some(def)
    | Some(opts) =>
      Some({
        base: ?pickOption(opts.base, def.base),
        resolve: ?pickOption(opts.resolve, def.resolve),
        validate: ?pickOption(opts.validate, def.validate),
        protocol: ?pickOption(opts.protocol, def.protocol),
        stripQuery: ?pickOption(opts.stripQuery, def.stripQuery),
        stripHash: ?pickOption(opts.stripHash, def.stripHash),
        attribute: ?pickOption(opts.attribute, def.attribute),
      })
    }
  }

let resolveDefaults = (defaults: option<schemaDefaults>, fieldType: fieldType): fieldType =>
  switch fieldType {
  | Text(opts) =>
    Text(
      mergeTextOptions(
        opts,
        switch defaults {
        | Some(d) => d.text
        | None => None
        },
      ),
    )
  | Attribute(cfg) => Attribute(cfg)
  | Html(opts) => Html(opts)
  | Number(opts) =>
    Number(
      mergeNumberOptions(
        opts,
        switch defaults {
        | Some(d) => d.number
        | None => None
        },
      ),
    )
  | Boolean(opts) =>
    Boolean(
      mergeBooleanOptions(
        opts,
        switch defaults {
        | Some(d) => d.boolean
        | None => None
        },
      ),
    )
  | Count(opts) => Count(opts)
  | Url(opts) =>
    Url(
      mergeUrlOptions(
        opts,
        switch defaults {
        | Some(d) => d.url
        | None => None
        },
      ),
    )
  | Json(opts) => Json(opts)
  | DateTime(opts) =>
    DateTime(
      mergeDateOptions(
        opts,
        switch defaults {
        | Some(d) => d.datetime
        | None => None
        },
      ),
    )
  | List(opts) => List(opts)
  | Table(opts) => Table(opts)
  }

let rec extractValue: (
  NodeHtmlParserBinding.htmlElement,
  fieldType,
  option<schemaDefaults>,
  bool,
) => result<JSON.t, schemaError> = (el, ft, defaults, ignoreErrors) => {
  switch resolveDefaults(defaults, ft) {
  | Text(opts) =>
    switch TextExtractor.extract(el, opts) {
    | Some(s) => Ok(JSON.Encode.string(s))
    | None => Ok(JSON.Encode.null)
    }
  | Html(opts) =>
    switch HtmlExtractor.extract(el, opts) {
    | Some(s) => Ok(JSON.Encode.string(s))
    | None => Ok(JSON.Encode.null)
    }
  | Attribute(cfg) =>
    switch AttributeExtractor.extract(el, cfg) {
    | Some(s) => Ok(JSON.Encode.string(s))
    | None => Ok(JSON.Encode.null)
    }
  | Number(opts) =>
    switch NumberExtractor.extract(el, opts) {
    | Some(n) => Ok(JSON.Encode.float(n))
    | None => Ok(JSON.Encode.null)
    }
  | Boolean(opts) =>
    switch BooleanExtractor.extract(el, opts) {
    | Ok(Some(b)) => Ok(JSON.Encode.bool(b))
    | Ok(None) => Ok(JSON.Encode.null)
    | Error(e) => Error(e)
    }
  | Url(opts) =>
    switch UrlExtractor.extract(el, opts) {
    | Some(s) => Ok(JSON.Encode.string(s))
    | None => Ok(JSON.Encode.null)
    }
  | Json(opts) =>
    switch JsonExtractor.extract(el, opts) {
    | Some(json) => Ok(json)
    | None => Ok(JSON.Encode.null)
    }
  | DateTime(opts) =>
    switch DateTimeExtractor.extract(el, opts) {
    | Some(s) => Ok(JSON.Encode.string(s))
    | None => Ok(JSON.Encode.null)
    }
  | Count(_) =>
    // Count requires the full element array; callers must use extractValueList.
    // If somehow routed here, return 1 (the element itself was found).
    Ok(JSON.Encode.int(1))
  | List(_) =>
    // List requires the full element array; callers must use extractValueList.
    Ok(JSON.Encode.null)
  | Table(tableOpts) => {
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
              tableOpts.columns->Array.reduce(Ok([]), (pAcc, col) => {
                switch pAcc {
                | Error(e) => Error(e)
                | Ok(pairs) => {
                    let value: result<JSON.t, schemaError> = switch col.columnType {
                    | ColumnList(opts) => {
                        let allEls = rowEl->NodeHtmlParserBinding.querySelectorAll(col.selector)
                        switch ListExtractor.extract(allEls, opts) {
                        | Some(json) => Ok(json)
                        | None => Ok(JSON.Encode.null)
                        }
                      }
                    | _ => {
                        let fieldType = columnTypeToFieldType(col.columnType)
                        switch rowEl
                        ->NodeHtmlParserBinding.querySelector(col.selector)
                        ->Nullable.toOption {
                        | Some(colEl) => extractValue(colEl, fieldType, defaults, ignoreErrors)
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
) => result<JSON.t, schemaError> = (els, ft, defaults, ignoreErrors) => {
  switch resolveDefaults(defaults, ft) {
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

/** Absence-aware variant for row contexts.
  * When the element was not found (`found = false`) and the field is
  * `Boolean(Presence)`, returns `false` instead of null. */
let extractValueOrAbsent: (
  option<NodeHtmlParserBinding.htmlElement>,
  fieldType,
  option<schemaDefaults>,
  bool,
) => result<JSON.t, schemaError> = (maybeEl, ft, defaults, ignoreErrors) => {
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
    | _ => Ok(JSON.Encode.null)
    }
  }
}
