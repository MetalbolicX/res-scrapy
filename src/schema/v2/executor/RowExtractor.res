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

  let results: result<array<JSON.t>, schemaError> = limitedRows->Array.reduce(Ok([]), (
    acc,
    rowEl,
  ) => {
    switch acc {
    | Error(e) => Error(e)
    | Ok(outputRows) => {
        let fieldResult: result<
          array<(string, JSON.t)>,
          schemaError,
        > = schema.fields->Array.reduce(Ok([]), (fAcc, (name, field)) => {
          switch fAcc {
          | Error(e) => Error(e)
          | Ok(pairs) => {
              let value: result<JSON.t, schemaError> = if isMultiElementType(field.fieldType) {
                // Multi-element path: pass all matched elements to extractValueList.
                let allEls = NodeHtmlParserBinding.querySelectorAll(rowEl, field.selector)
                Ok(ExtractorRegistry.extractValueList(allEls, field.fieldType))
              } else {
                let maybeEl =
                  NodeHtmlParserBinding.querySelector(rowEl, field.selector)->Nullable.toOption
                switch maybeEl {
                | Some(el) => Ok(ExtractorRegistry.extractValue(el, field.fieldType))
                | None =>
                  // Boolean(Presence) → false when absent
                  let presenceFalse = switch field.fieldType {
                  | Boolean(opts) =>
                    switch opts {
                    | Some({mode: Presence}) => true
                    | _ => false
                    }
                  | _ => false
                  }
                  if presenceFalse {
                    Ok(JSON.Encode.bool(false))
                  } else if field.required && schema.config.ignoreErrors == false {
                    Error(RequiredFieldMissing({fieldName: name, selector: field.selector}))
                  } else {
                    Ok(
                      switch field.default {
                      | Some(d) => JSON.Encode.string(d)
                      | None => JSON.Encode.null
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
        })
        switch fieldResult {
        | Error(e) => Error(e)
        | Ok(pairs) => {
            outputRows->Array.push(JSON.Encode.object(Dict.fromArray(pairs)))
            Ok(outputRows)
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
