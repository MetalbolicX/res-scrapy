/** Zip-based extraction strategy (column-oriented).
  *
  * Each field selector runs against the document root independently.
  * Rows are produced by zipping element lists by index.
  * This mirrors the v1 behaviour and is the default when no rowSelector is set.
  *
  * Count fields are aggregate by nature and do not participate in the index
  * zip — they receive the full element array via extractValueList and their
  * result is the same across every output row.
  */

open FieldTypes

module Iter = NodeJsBinding.Iter

let run: (NodeHtmlParserBinding.htmlElement, schema) => result<JSON.t, schemaError> = (
  document,
  schema,
) => {
  let fieldLists =
    schema.fields
    ->Iter.values
    ->Iter.map(((name, field)) => {
      let resolvedFieldType = DefaultsMerger.resolveDefaults(schema.config.defaults, field.fieldType)
      let nestedDefaults = switch resolvedFieldType {
      | Table(_) => schema.config.defaults
      | _ => None
      }
      let els = NodeHtmlParserBinding.querySelectorAll(document, field.selector)
      (name, field, resolvedFieldType, nestedDefaults, els)
    })
    ->Iter.toArray

  let aggregateValues: Dict.t<result<JSON.t, schemaError>> = Dict.make()
  fieldLists->Iter.values->Iter.forEach(((name, field, resolvedFieldType, _nestedDefaults, els)) => {
    if isMultiElementType(resolvedFieldType) {
      let value = ExtractorRegistry.extractValueList(
        els,
        resolvedFieldType,
        None,
        schema.config.ignoreErrors,
        field.required,
        name,
        field.selector,
      )
      Dict.set(aggregateValues, name, value)
    }
  })

  // Row count is driven by the first non-aggregate field's element count.
  // Aggregate fields (Count/List) produce a single value per output row regardless.
  // Edge case: if all fields are aggregate and rowSelector is not set, rowCount
  // is 0 and the output is an empty array. Use rowSelector to enable row-based
  // extraction in that scenario.
  let rowCount = switch fieldLists->Iter.values->Iter.find(((_, _, resolvedFieldType, _, _)) =>
    !isMultiElementType(resolvedFieldType)
  ) {
  | None => 0
  | Some((_, _, _, _, els)) => Array.length(els)
  }

  let limitedCount = switch schema.config.limit {
  | 0 => rowCount
  | n => n < rowCount ? n : rowCount
  }

  let rec buildRows = (idx: int, rows: array<JSON.t>): result<array<JSON.t>, schemaError> => {
    if idx >= limitedCount {
      Ok(rows)
    } else {
      let fieldResult: result<array<(string, JSON.t)>, schemaError> =
        fieldLists->Iter.values->Iter.reduce((fAcc, (name, field, resolvedFieldType, nestedDefaults, els)) => {
          switch fAcc {
          | Error(e) => Error(e)
          | Ok(pairs) => {
              let value: result<JSON.t, schemaError> = if isMultiElementType(resolvedFieldType) {
                switch Dict.get(aggregateValues, name) {
                | Some(v) => v
                | None => Ok(JSON.Encode.null)
                }
              } else {
                switch Array.get(els, idx) {
                | Some(el) =>
                  ExtractorRegistry.extractValue(
                    el,
                    resolvedFieldType,
                    nestedDefaults,
                    schema.config.ignoreErrors,
                  )
                | None =>
                  if field.required && schema.config.ignoreErrors == false {
                    Error(RequiredFieldMissing({fieldName: name, selector: field.selector}))
                  } else {
                    Ok(switch field.default {
                    | Some(d) => d
                    | None => JSON.Encode.null
                    })
                  }
                }
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
          rows->Array.push(JSON.Encode.object(Dict.fromArray(pairs)))
          buildRows(idx + 1, rows)
        }
      }
    }
  }

  let results: result<array<JSON.t>, schemaError> = buildRows(0, [])

  switch results {
  | Error(e) => Error(e)
  | Ok(arr) => Ok(JSON.Encode.array(arr))
  }
}

module Strategy = ExtractionStrategy.Make({
  let name = "zip"
  let canHandle = (_schema: schema) => true
  let run = run
})
