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

module Iter = NodeIter

let run: (NodeHtmlParserBinding.htmlElement, schema) => result<JSON.t, schemaError> = (
  document,
  schema,
) => {
  let fieldLists =
    schema.fields
    ->Iter.values
    ->Iter.map(((name, field)) => {
      let resolvedFieldType = DefaultsMerger.resolveDefaults(
        schema.config.defaults,
        field.fieldType,
      )
      let nestedDefaults = switch resolvedFieldType {
      | Table(_) => schema.config.defaults
      | _ => None
      }
      let els = NodeHtmlParserBinding.querySelectorAll(document, field.selector)
      (name, field, resolvedFieldType, nestedDefaults, els)
    })
    ->Iter.toArray

  let aggregateValues: Dict.t<result<JSON.t, schemaError>> = Dict.make()
  fieldLists
  ->Iter.values
  ->Iter.forEach(((name, field, resolvedFieldType, _nestedDefaults, els)) => {
    if isMultiElementType(resolvedFieldType) {
      let value = ExtractorRegistry.extractValueList(
        els,
        resolvedFieldType,
        {
          defaults: None,
          ignoreErrors: schema.config.ignoreErrors,
          required: field.required,
          fieldName: name,
          selector: field.selector,
        },
      )
      Dict.set(aggregateValues, name, value)
    }
  })

  // Ordinary scalars drive zip rows; Count/List/joined Text are broadcast.
  // Only when ordinary scalars are absent can matched joined Text create one row.
  // Count/List-only schemas retain their zero-row behavior.
  let scalarCount = fieldLists->Iter.values->Iter.reduce((maximum, (_, _, ft, _, els)) => {
      if isMultiElementType(ft) {
        maximum
      } else {
        let count = Array.length(els)
        let previous = maximum->Option.getOr(0)
        Some(count > previous ? count : previous)
      }
    }, None)
  let rowCount = switch scalarCount {
  | None =>
    let matchedJoin =
      fieldLists
      ->Iter.values
      ->Iter.find(((_, _, ft, _, els)) =>
        switch ft {
        | Text(Some(opts)) => opts.join->Option.isSome && Array.length(els) > 0
        | _ => false
        }
      )
    matchedJoin->Option.isSome ? 1 : 0
  | Some(count) => count
  }

  let limitedCount = switch schema.config.limit {
  | 0 => rowCount
  | n => n < rowCount ? n : rowCount
  }

  let buildRows = (): result<array<JSON.t>, schemaError> => {
    let rows: array<JSON.t> = []
    let idx = ref(0)
    let loopResult: ref<result<unit, schemaError>> = ref(Ok())
    while (
      idx.contents < limitedCount &&
        {
          switch loopResult.contents {
          | Error(_) => false
          | Ok(_) => true
          }
        }
    ) {
      let fieldResult: result<array<(string, JSON.t)>, schemaError> =
        fieldLists
        ->Iter.values
        ->Iter.reduce((fAcc, (name, field, resolvedFieldType, nestedDefaults, els)) => {
          switch fAcc {
          | Error(e) => Error(e)
          | Ok(pairs) => {
              let value: result<JSON.t, schemaError> = if isMultiElementType(resolvedFieldType) {
                switch Dict.get(aggregateValues, name) {
                | Some(v) => v
                | None => Ok(JSON.Encode.null)
                }
              } else {
                switch els[idx.contents] {
                | Some(el) =>
                  ExtractorRegistry.extractValue(
                    el,
                    resolvedFieldType,
                    {
                      defaults: nestedDefaults,
                      ignoreErrors: schema.config.ignoreErrors,
                      required: field.required,
                      fieldName: name,
                      selector: field.selector,
                    },
                  )
                | None =>
                  if field.required && schema.config.ignoreErrors == false {
                    Error(RequiredFieldMissing({fieldName: name, selector: field.selector}))
                  } else {
                    Ok(
                      switch field.default {
                      | Some(d) => d
                      | None =>
                        switch resolvedFieldType {
                        | Boolean(Some({mode: Presence})) => JSON.Encode.bool(false)
                        | _ => JSON.Encode.null
                        }
                      },
                    )
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
      | Error(e) => loopResult := Error(e)
      | Ok(pairs) => {
          let rowObj = Dict.make()
          pairs->Array.forEach(((k, v)) => Dict.set(rowObj, k, v))
          rows->Array.push(JSON.Encode.object(rowObj))
          idx := idx.contents + 1
        }
      }
    }
    switch loopResult.contents {
    | Error(e) => Error(e)
    | Ok(_) => Ok(rows)
    }
  }

  let results: result<array<JSON.t>, schemaError> = buildRows()

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
