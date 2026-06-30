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

  let preQueriedFields = resolvedFields->Array.map(((name, field, resolvedFieldType, nestedDefaults)) => {
    let isMulti = isMultiElementType(resolvedFieldType)
    let perRowEls = limitedRows->Array.map(rowEl =>
      if isMulti {
        NodeHtmlParserBinding.querySelectorAll(rowEl, field.selector)
      } else {
        switch NodeHtmlParserBinding.querySelector(rowEl, field.selector)->Nullable.toOption {
        | Some(el) => [el]
        | None => []
        }
      }
    )
    (name, field, resolvedFieldType, nestedDefaults, perRowEls)
  })

  let outputRows: array<JSON.t> = []
  let rowCount = Array.length(limitedRows)
  let rowIdx = ref(0)
  let loopResult: ref<result<unit, schemaError>> = ref(Ok())

  while rowIdx.contents < rowCount {
    switch loopResult.contents {
    | Error(_) => rowIdx := rowCount
    | Ok(_) => {
        let pairsResult: result<array<(string, JSON.t)>, schemaError> = {
          let pairs: array<(string, JSON.t)> = []
          let fieldError: ref<option<schemaError>> = ref(None)
          preQueriedFields->Array.forEach(((name, field, resolvedFieldType, nestedDefaults, perRowEls)) => {
            switch fieldError.contents {
            | Some(_) => ()
            | None => {
                let rowEls = Array.get(perRowEls, rowIdx.contents)->Option.getOr([])
                let value = if isMultiElementType(resolvedFieldType) {
                  ExtractorRegistry.extractValueList(
                    rowEls,
                    resolvedFieldType,
                    None,
                    schema.config.ignoreErrors,
                    field.required,
                    name,
                    field.selector,
                  )
                } else {
                  let maybeEl = Array.get(rowEls, 0)
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
                | Error(e) => fieldError := Some(e)
                | Ok(v) => pairs->Array.push((name, v))
                }
              }
            }
          })
          switch fieldError.contents {
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

  let results = switch loopResult.contents {
  | Error(e) => Error(e)
  | Ok(_) => Ok(outputRows)
  }

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
