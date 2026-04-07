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

/** Returns true for field types that need the full element array. */
let isMultiElementType: fieldType => bool = ft =>
  switch ft {
  | Count(_) => true
  | List(_) => true
  | _ => false
  }

let run: (NodeHtmlParserBinding.htmlElement, schema) => result<JSON.t, schemaError> = (
  document,
  schema,
) => {
  let fieldLists = schema.fields->Array.map(((name, field)) => (
    name,
    field,
    NodeHtmlParserBinding.querySelectorAll(document, field.selector),
  ))

  // Row count is driven by the first non-aggregate field's element count.
  // Aggregate fields (Count) produce a single value per output row regardless.
  let rowCount = switch fieldLists->Array.find(((_, field, _)) =>
    !isMultiElementType(field.fieldType)
  ) {
  | None => 0
  | Some((_, _, els)) => Array.length(els)
  }

  let limitedCount = switch schema.config.limit {
  | 0 => rowCount
  | n => n < rowCount ? n : rowCount
  }

  let results: result<array<JSON.t>, schemaError> =
    Array.make(~length=limitedCount, ())->Array.reduce(Ok([]), (acc, _) => {
      switch acc {
      | Error(e) => Error(e)
      | Ok(rows) => {
          let idx = Array.length(rows)
          let fieldResult: result<array<(string, JSON.t)>, schemaError> =
            fieldLists->Array.reduce(Ok([]), (fAcc, (name, field, els)) => {
              switch fAcc {
              | Error(e) => Error(e)
              | Ok(pairs) => {
                  let value: result<JSON.t, schemaError> = if isMultiElementType(field.fieldType) {
                    // Aggregate path: pass the full element array; result is the
                    // same for every row (e.g., total count across the document).
                    ExtractorRegistry.extractValueList(els, field.fieldType, schema.config.defaults)
                  } else {
                    switch Array.get(els, idx) {
                    | Some(el) =>
                      ExtractorRegistry.extractValue(el, field.fieldType, schema.config.defaults)
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
            })
          switch fieldResult {
          | Error(e) => Error(e)
          | Ok(pairs) => {
              rows->Array.push(JSON.Encode.object(Dict.fromArray(pairs)))
              Ok(rows)
            }
          }
        }
      }
    })

  switch results {
  | Error(e) => Error(e)
  | Ok(arr) => Ok(JSON.Encode.array(arr))
  }
}
