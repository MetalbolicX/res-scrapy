/** Row-based extraction strategy.
  *
  * When schema.config.rowSelector is set, this extractor queries all row
  * elements first, then evaluates each field selector *relative to each row*.
  * This produces one output object per row element.
  *
  * Boolean(Presence) fields return false when the sub-selector finds nothing.
  * Count fields use querySelectorAll and extractValueList (multi-element path).
  */
open FieldTypes

module Iter = NodeJsBinding.Iter

let run: (NodeHtmlParserBinding.htmlElement, schema) => result<JSON.t, schemaError> = (
  document,
  schema,
) => {
  let rowSelector = switch schema.config.rowSelector {
  | Some(s) => s
  | None => "*"
  }

  let rows = NodeHtmlParserBinding.querySelectorAll(document, rowSelector)

  let limitedRows = switch schema.config.limit {
  | 0 => rows
  | n =>
    if n < Array.length(rows) {
      Array.slice(rows, ~start=0, ~end=n)
    } else {
      rows
    }
  }

  let resolvedFields =
    schema.fields
    ->Iter.values
    ->Iter.map(((name, field)) => {
      let resolvedFieldType = DefaultsMerger.resolveDefaults(schema.config.defaults, field.fieldType)
      let nestedDefaults = switch resolvedFieldType {
      | Table(_) => schema.config.defaults
      | _ => None
      }
      (name, field, resolvedFieldType, nestedDefaults)
    })
    ->Iter.toArray

  let results: result<array<JSON.t>, schemaError> = limitedRows->Iter.values->Iter.reduce((
    acc,
    rowEl,
  ) => {
    switch acc {
    | Error(e) => Error(e)
    | Ok(outputRows) => {
        let fieldResult: result<
          array<(string, JSON.t)>,
          schemaError,
        > = resolvedFields->Iter.values->Iter.reduce((fAcc, (name, field, resolvedFieldType, nestedDefaults)) => {
          switch fAcc {
          | Error(e) => Error(e)
          | Ok(pairs) => {
                let value: result<JSON.t, schemaError> = if isMultiElementType(resolvedFieldType) {
                  // Multi-element path: pass all matched elements to extractValueList.
                  let allEls = NodeHtmlParserBinding.querySelectorAll(rowEl, field.selector)
                  ExtractorRegistry.extractValueList(
                    allEls,
                    resolvedFieldType,
                    None,
                    schema.config.ignoreErrors,
                    field.required,
                    name,
                    field.selector,
                  )
                } else {
                  let maybeEl =
                    NodeHtmlParserBinding.querySelector(rowEl, field.selector)->Nullable.toOption
                  ExtractorRegistry.extractValueOrAbsent(
                    maybeEl,
                    resolvedFieldType,
                    field.default,
                    field.required,
                    name,
                    field.selector,
                    nestedDefaults,
                    schema.config.ignoreErrors,
                  )
                }
              switch value {
              | Error(e) => Error(e)
              | Ok(v) => {
                  pairs->Array.push((name, v))
                  Ok(pairs)
                }
              }
            }
          }
        }, Ok([]))
        switch fieldResult {
        | Error(e) => Error(e)
        | Ok(pairs) => {
            outputRows->Array.push(JSON.Encode.object(Dict.fromArray(pairs)))
            Ok(outputRows)
          }
        }
      }
    }
  }, Ok([]))

  switch results {
  | Error(e) => Error(e)
  | Ok(arr) => Ok(JSON.Encode.array(arr))
  }
}

module Strategy = ExtractionStrategy.Make({
  let name = "row"
  let canHandle = (schema: schema) => schema.config.rowSelector->Option.isSome
  let run = run
})
