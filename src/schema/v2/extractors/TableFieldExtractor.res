/** Table field extraction lifted out of ExtractorRegistry.
  *
  * The single field-type dispatch (visitor) that produces JSON for scalar,
  * attribute, boolean, list, etc. fields still lives in ExtractorRegistry.
  * Table extraction needs to recurse into that same dispatch to resolve each
  * cell value, so the recursive extractor is passed in as a callback. */
open FieldTypes

module Iter = NodeJsBinding.Iter

/** Callback signature for resolving a single (non-list) cell value inside a
  * row. This is satisfied by `ExtractorRegistry.extractValue` and lets the
  * table logic stay module-scoped without a circular dependency. */
type cellExtractor = (
  NodeHtmlParserBinding.htmlElement,
  fieldType,
  option<schemaDefaults>,
  bool,
) => result<JSON.t, schemaError>

let resolveRows: (
  NodeHtmlParserBinding.htmlElement,
  option<string>,
) => array<NodeHtmlParserBinding.htmlElement> = (el, rowSelector) => {
  switch rowSelector {
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
}

let columnTypeToFieldType: columnFieldType => fieldType = columnType => {
  let visitor: FieldTypeVisitor.columnFieldTypeVisitor<fieldType> = {
    columnText: opts => Text(opts),
    columnAttribute: cfg => Attribute(cfg),
    columnHtml: opts => Html(opts),
    columnNumber: opts => Number(opts),
    columnBoolean: opts => Boolean(opts),
    columnUrl: opts => Url(opts),
    columnJson: opts => Json(opts),
    columnDateTime: opts => DateTime(opts),
    columnList: opts => List(opts),
  }
  FieldTypeVisitor.visitColumnFieldType(visitor, columnType)
}

let resolveColumnDefaults: (
  columnField,
  option<schemaDefaults>,
) => (fieldType, option<schemaDefaults>) = (col, defaults) => {
  let resolvedFieldType = switch col.columnType {
  | ColumnList(opts) => List(opts)
  | _ => DefaultsMerger.resolveDefaults(defaults, columnTypeToFieldType(col.columnType))
  }
  let nestedDefaults = switch resolvedFieldType {
  | Table(_) => defaults
  | _ => None
  }
  (resolvedFieldType, nestedDefaults)
}

let extract: (
  NodeHtmlParserBinding.htmlElement,
  tableOptions,
  option<schemaDefaults>,
  bool,
  cellExtractor,
) => result<JSON.t, schemaError> = (el, tableOpts, defaults, ignoreErrors, extractCell) => {
  let resolvedColumns = tableOpts.columns
    ->Iter.values
    ->Iter.map(col => {
      let (resolvedFieldType, nestedDefaults) = resolveColumnDefaults(col, defaults)
      (col, resolvedFieldType, nestedDefaults)
    })
    ->Iter.toArray

  let rows = resolveRows(el, tableOpts.rowSelector)

  let rowsResult: result<array<JSON.t>, schemaError> = rows
    ->Iter.values
    ->Iter.reduce((acc, rowEl) => {
      switch acc {
      | Error(e) => Error(e)
      | Ok(outputRows) => {
          let pairsResult: result<array<(string, JSON.t)>, schemaError> =
            resolvedColumns
            ->Iter.values
            ->Iter.reduce((pAcc, (col, resolvedFieldType, nestedDefaults)) => {
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
                  | _ =>
                    switch rowEl
                    ->NodeHtmlParserBinding.querySelector(col.selector)
                    ->Nullable.toOption {
                    | Some(colEl) =>
                      extractCell(colEl, resolvedFieldType, nestedDefaults, ignoreErrors)
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
            }, Ok([]))

          switch pairsResult {
          | Error(e) => Error(e)
          | Ok(pairs) => {
              outputRows->Array.push(JSON.Encode.object(Dict.fromArray(pairs)))
              Ok(outputRows)
            }
          }
        }
      }
    }, Ok([]))

  switch rowsResult {
  | Error(e) => Error(e)
  | Ok(arr) => Ok(JSON.Encode.array(arr))
  }
}