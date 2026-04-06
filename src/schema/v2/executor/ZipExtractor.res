/** Zip-based extraction strategy (column-oriented).
  *
  * Each field selector runs against the document root independently.
  * Rows are produced by zipping element lists by index.
  * This mirrors the v1 behaviour and is the default when no rowSelector is set.
  */

open FieldTypes

let run: (NodeHtmlParserBinding.htmlElement, schema) => result<JSON.t, schemaError> = (
  document,
  schema,
) => {
  let fieldLists = schema.fields->Array.map(((name, field)) => (
    name,
    field,
    NodeHtmlParserBinding.querySelectorAll(document, field.selector),
  ))

  let rowCount = switch fieldLists->Array.get(0) {
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
                  let value: result<JSON.t, schemaError> = switch Array.get(els, idx) {
                  | Some(el) => Ok(ExtractorRegistry.extractValue(el, field.fieldType))
                  | None =>
                    if field.required && schema.config.ignoreErrors == false {
                      Error(RequiredFieldMissing({fieldName: name, selector: field.selector}))
                    } else {
                      Ok(switch field.default {
                      | Some(d) => JSON.Encode.string(d)
                      | None => JSON.Encode.null
                      })
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
