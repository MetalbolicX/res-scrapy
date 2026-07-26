/** Table field extraction lifted out of ExtractorRegistry.
  *
  * The single field-type dispatch (visitor) that produces JSON for scalar,
  * attribute, boolean, list, etc. fields still lives in ExtractorRegistry.
  * Table extraction needs to recurse into that same dispatch to resolve each
  * cell value, so the recursive extractor is passed in as a callback. */
open FieldTypes

module Iter = NodeIter

/** Callback signature for resolving a single (non-list) cell value inside a
  * row. This is satisfied by `ExtractorRegistry.extractValue` and lets the
  * table logic stay module-scoped without a circular dependency. */
type cellExtractor = (
  NodeHtmlParserBinding.htmlElement,
  fieldType,
  extractContext,
) => result<JSON.t, schemaError>

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
  extractContext,
  cellExtractor,
) => result<JSON.t, schemaError> = (el, tableOpts, ctx, extractCell) => {
  let defaults = ctx.defaults
  let ignoreErrors = ctx.ignoreErrors
  let resolvedColumns =
    tableOpts.columns
    ->Iter.values
    ->Iter.map(col => {
      let (resolvedFieldType, nestedDefaults) = resolveColumnDefaults(col, defaults)
      (col, resolvedFieldType, nestedDefaults)
    })
    ->Iter.toArray

  let rows = TableUtils.resolveRows(el, tableOpts.rowSelector)

  let preQueriedCols = resolvedColumns->Array.map(((col, resolvedFieldType, nestedDefaults)) => {
    let isList = switch resolvedFieldType {
    | List(_) => true
    | _ => false
    }
    let perRowEls = rows->Array.map(rowEl =>
      if isList {
        NodeHtmlParserBinding.querySelectorAll(rowEl, col.selector)
      } else {
        switch rowEl->NodeHtmlParserBinding.querySelector(col.selector)->Nullable.toOption {
        | Some(el) => [el]
        | None => []
        }
      }
    )
    (col, resolvedFieldType, nestedDefaults, perRowEls)
  })

  let outputRows: array<JSON.t> = []
  let rowCount = Array.length(rows)
  let rowIdx = ref(0)
  let loopResult: ref<result<unit, schemaError>> = ref(Ok())

  while rowIdx.contents < rowCount {
    switch loopResult.contents {
    | Error(_) => rowIdx := rowCount
    | Ok(_) => {
        let pairsResult: result<array<(string, JSON.t)>, schemaError> = {
          let pairs: array<(string, JSON.t)> = []
          let pairsError: ref<option<schemaError>> = ref(None)
          preQueriedCols->Array.forEach(((col, resolvedFieldType, nestedDefaults, perRowEls)) => {
            switch pairsError.contents {
            | Some(_) => ()
            | None => {
                let rowEls = perRowEls[rowIdx.contents]->Option.getOr([])
                let value: result<JSON.t, schemaError> = switch resolvedFieldType {
                | List(opts) =>
                  switch ListExtractor.extract(rowEls, opts) {
                  | Some(json) => Ok(json)
                  | None => Ok(JSON.Encode.null)
                  }
                | _ =>
                  let maybeEl = rowEls[0]
                  switch maybeEl {
                  | Some(colEl) =>
                    extractCell(
                      colEl,
                      resolvedFieldType,
                      {
                        defaults: nestedDefaults,
                        ignoreErrors,
                        required: col.required,
                        fieldName: col.name,
                        selector: col.selector,
                      },
                    )
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
                  } else {
                    pairsError := Some(e)
                  }
                | Ok(v) => pairs->Array.push((col.name, v))
                }
              }
            }
          })
          switch pairsError.contents {
          | Some(e) => Error(e)
          | None => Ok(pairs)
          }
        }
        switch pairsResult {
        | Error(e) => loopResult := Error(e)
        | Ok(pairs) => outputRows->Array.push(JSON.Encode.object(Dict.fromArray(pairs)))
        }
        rowIdx := rowIdx.contents + 1
      }
    }
  }

  let rowsResult = switch loopResult.contents {
  | Error(e) => Error(e)
  | Ok(_) => Ok(outputRows)
  }

  switch rowsResult {
  | Error(e) => Error(e)
  | Ok(arr) => Ok(JSON.Encode.array(arr))
  }
}
