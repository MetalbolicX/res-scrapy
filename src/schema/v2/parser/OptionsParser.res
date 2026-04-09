/** Parse per-field option objects from raw JSON values.
  * Each function accepts the raw JSON dict for a field and returns the
  * appropriate option record, falling back to None when the key is absent.
  */

open FieldTypes

@get_index external dictGet: ({..}, string) => option<'a> = ""

// ---------------------------------------------------------------------------
// text options
// ---------------------------------------------------------------------------

let parseTextOptions: {..} => option<textOptions> = fieldJson => {
  switch dictGet(fieldJson, "textOptions") {
  | None => None
  | Some(raw) => {
      let trim = dictGet(raw, "trim")
      let normalizeWhitespace = dictGet(raw, "normalizeWhitespace")
      let lowercase = dictGet(raw, "lowercase")
      let uppercase = dictGet(raw, "uppercase")
      let pattern = dictGet(raw, "pattern")
      let join = dictGet(raw, "join")
      Some({?trim, ?normalizeWhitespace, ?lowercase, ?uppercase, ?pattern, ?join})
    }
  }
}

// ---------------------------------------------------------------------------
// html options
// ---------------------------------------------------------------------------

let parseHtmlOptions: {..} => option<htmlOptions> = fieldJson => {
  switch dictGet(fieldJson, "htmlOptions") {
  | None => None
  | Some(raw) => {
      let mode = switch dictGet(raw, "mode") {
      | Some("outer") => Some(Outer)
      | _ => Some(Inner)
      }
      let stripScripts = dictGet(raw, "stripScripts")
      let stripStyles = dictGet(raw, "stripStyles")
      Some({?mode, ?stripScripts, ?stripStyles})
    }
  }
}

// ---------------------------------------------------------------------------
// attribute config
// ---------------------------------------------------------------------------

let parseAttributeConfig: {..} => option<attributeConfig> = fieldJson => {
  // Support both "attribute" (string, legacy) and "attributes" (array) keys
  switch dictGet(fieldJson, "attributes") {
  | Some(arr) => {
      let rawMode: option<string> = switch dictGet(fieldJson, "attrMode") {
      | Some(m) => Some(m)
      | None =>
        switch dictGet(fieldJson, "attributeOptions") {
        | Some(opts) => dictGet(opts, "mode")
        | None => None
        }
      }
      let mode = switch rawMode {
      | Some("firstNonEmpty") => FirstNonEmpty
      | Some("all") => All
      | Some("join") => Join
      | _ => First
      }
      let joinSep: option<string> = switch dictGet(fieldJson, "attributeOptions") {
      | Some(opts) => dictGet(opts, "joinSep")
      | None => None
      }
      Some({names: arr, mode, ?joinSep})
    }
  | None =>
    // Legacy: "attribute": "href" — single key string
    switch dictGet(fieldJson, "attribute") {
    | Some(name) => Some({names: [name], mode: First})
    | None => None
    }
  }
}

// ---------------------------------------------------------------------------
// number options
// ---------------------------------------------------------------------------

let parseErrorPolicy: string => errorPolicy = s => switch s {
| "returnText" => ReturnText
| "returnDefault" => ReturnDefault
| _ => ReturnNull
}

let parseNumberOptions: {..} => option<numberOptions> = fieldJson => {
  switch dictGet(fieldJson, "numberOptions") {
  | None => None
  | Some(raw) => {
      let stripNonNumeric = dictGet(raw, "stripNonNumeric")
      let pattern = dictGet(raw, "pattern")
      let thousandsSeparator = dictGet(raw, "thousandsSeparator")
      let decimalSeparator = dictGet(raw, "decimalSeparator")
      let precision = dictGet(raw, "precision")
      let allowNegative = dictGet(raw, "allowNegative")
      let onError = switch dictGet(raw, "onError") {
      | Some(s) => Some(parseErrorPolicy(s))
      | None => None
      }
      Some({?stripNonNumeric, ?pattern, ?thousandsSeparator, ?decimalSeparator,
            ?precision, ?allowNegative, ?onError})
    }
  }
}

// ---------------------------------------------------------------------------
// count options
// ---------------------------------------------------------------------------

let parseCountOptions: {..} => option<countOptions> = fieldJson => {
  switch dictGet(fieldJson, "countOptions") {
  | None => None
  | Some(raw) => {
      let min = dictGet(raw, "min")
      let max = dictGet(raw, "max")
      Some({?min, ?max})
    }
  }
}

// ---------------------------------------------------------------------------
// url options
// ---------------------------------------------------------------------------

let parseUrlOptions: {..} => option<urlOptions> = fieldJson => {
  switch dictGet(fieldJson, "urlOptions") {
  | None => None
  | Some(raw) => {
      let base = dictGet(raw, "base")
      let resolve = dictGet(raw, "resolve")
      let validate = dictGet(raw, "validate")
      let protocol = dictGet(raw, "protocol")
      let stripQuery = dictGet(raw, "stripQuery")
      let stripHash = dictGet(raw, "stripHash")
      let attribute = dictGet(raw, "attribute")
      Some({?base, ?resolve, ?validate, ?protocol, ?stripQuery, ?stripHash, ?attribute})
    }
  }
}

// ---------------------------------------------------------------------------
// json options
// ---------------------------------------------------------------------------

let parseJsonOptions: {..} => option<jsonOptions> = fieldJson => {
  switch dictGet(fieldJson, "jsonOptions") {
  | None => None
  | Some(raw) => {
      let source = dictGet(raw, "source")
      let attribute = dictGet(raw, "attribute")
      let path = dictGet(raw, "path")
      let onError = switch dictGet(raw, "onError") {
      | Some(s) => Some(parseErrorPolicy(s))
      | None => None
      }
      Some({?source, ?attribute, ?path, ?onError})
    }
  }
}

// ---------------------------------------------------------------------------
// datetime options
// ---------------------------------------------------------------------------

let parseDateOutput: ({..}, option<string>) => option<dateOutput> = (raw, maybeKey) => {
  let key = Option.getOr(maybeKey, "output")
  switch dictGet(raw, key) {
  | None => None
  | Some("iso8601") => Some(Iso8601)
  | Some("epoch") => Some(Epoch)
  | Some("epochMillis") => Some(EpochMillis)
  | Some("custom") => {
      let fmt: string = switch dictGet(raw, "outputFormat") {
      | Some(f) => f
      | None => "yyyy-MM-dd"
      }
      Some(Custom(fmt))
    }
  | Some(_) => None
  }
}

let parseDateOptions: {..} => option<dateOptions> = fieldJson => {
  switch dictGet(fieldJson, "dateOptions") {
  | None => None
  | Some(raw) => {
      let formats = dictGet(raw, "formats")
      let timezone = dictGet(raw, "timezone")
      let output = parseDateOutput(raw, Some("output"))
      let strict = dictGet(raw, "strict")
      let source = dictGet(raw, "source")
      let attribute = dictGet(raw, "attribute")
      Some({?formats, ?timezone, ?output, ?strict, ?source, ?attribute})
    }
  }
}

// ---------------------------------------------------------------------------
// list options
// ---------------------------------------------------------------------------

let parseListItemType: string => listItemType = s => {
  if String.startsWith(s, "attr:") {
    let attrName = String.slice(s, ~start=5, ~end=String.length(s))
    ListAttribute(attrName)
  } else {
    switch s {
    | "html" => ListHtml
    | "url" => ListUrl
    | _ => ListText
    }
  }
}

let parseListOptions: {..} => listOptions = fieldJson => {
  let raw: option<{..}> = dictGet(fieldJson, "listOptions")
  let itemType = switch raw {
  | Some(r) =>
    switch dictGet(r, "itemType") {
    | Some(s) => parseListItemType(s)
    | None => ListText
    }
  | None => ListText
  }
  let unique: option<bool> = switch raw {
  | Some(r) => dictGet(r, "unique")
  | None => None
  }
  let filter: option<string> = switch raw {
  | Some(r) => dictGet(r, "filter")
  | None => None
  }
  let limit: option<int> = switch raw {
  | Some(r) => dictGet(r, "limit")
  | None => None
  }
  let join: option<string> = switch raw {
  | Some(r) => dictGet(r, "join")
  | None => None
  }
  {itemType, ?unique, ?filter, ?limit, ?join}
}

// ---------------------------------------------------------------------------
// boolean options
// ---------------------------------------------------------------------------

let parseBooleanMode: string => booleanMode = s => switch s {
| "presence" => Presence
| "attributeCheck" => AttributeCheck
| _ => Mapping
}

let parseBooleanUnknownPolicy: string => booleanUnknownPolicy = s => switch s {
| "null" => UnknownNull
| "error" => UnknownError
| _ => UnknownFalse
}

let parseBooleanOptions: {..} => option<booleanOptions> = fieldJson => {
  switch dictGet(fieldJson, "booleanOptions") {
  | None => None
  | Some(raw) => {
      let mode = switch dictGet(raw, "mode") {
      | Some(m) => Some(parseBooleanMode(m))
      | None => None
      }
      let trueValues = dictGet(raw, "trueValues")
      let falseValues = dictGet(raw, "falseValues")
      let attribute = dictGet(raw, "attribute")
      let onUnknown = switch dictGet(raw, "onUnknown") {
      | Some(s) => Some(parseBooleanUnknownPolicy(s))
      | None => None
      }
      Some({?mode, ?trueValues, ?falseValues, ?attribute, ?onUnknown})
    }
  }
}

// ---------------------------------------------------------------------------
// table options
// ---------------------------------------------------------------------------

let parseColumnFieldType: ({..}, string) => result<columnFieldType, string> = (columnJson, typeName) => {
  switch typeName {
  | "text" => Ok(ColumnText(parseTextOptions(columnJson)))
  | "html" => Ok(ColumnHtml(parseHtmlOptions(columnJson)))
  | "number" => Ok(ColumnNumber(parseNumberOptions(columnJson)))
  | "boolean" | "bool" => Ok(ColumnBoolean(parseBooleanOptions(columnJson)))
  | "url" => Ok(ColumnUrl(parseUrlOptions(columnJson)))
  | "json" => Ok(ColumnJson(parseJsonOptions(columnJson)))
  | "datetime" => Ok(ColumnDateTime(parseDateOptions(columnJson)))
  | "list" => Ok(ColumnList(parseListOptions(columnJson)))
  | "attribute" =>
    switch parseAttributeConfig(columnJson) {
    | Some(cfg) => Ok(ColumnAttribute(cfg))
    | None => Error("attribute column requires an \"attribute\" or \"attributes\" key")
    }
  | "count" => Error("table column type \"count\" is not supported")
  | "table" => Error("nested table columns are not supported")
  | other => Error(`Unknown column type: "${other}"`)
  }
}

let parseColumnField: {..} => result<columnField, string> = columnJson => {
  switch (dictGet(columnJson, "name"), dictGet(columnJson, "selector")) {
  | (Some(name), Some(selector)) => {
      let rawType: string = switch dictGet(columnJson, "type") {
      | Some(t) => t
      | None => "text"
      }
      switch parseColumnFieldType(columnJson, rawType) {
      | Error(msg) => Error(msg)
      | Ok(columnType) => {
          let required: bool = (dictGet(columnJson, "required"): option<bool>)->Option.getOr(false)
          let default: option<JSON.t> = dictGet(columnJson, "default")
          Ok({name, selector, columnType, required, ?default})
        }
      }
    }
  | (None, _) => Error("table column is missing required key \"name\"")
  | (_, None) => Error("table column is missing required key \"selector\"")
  }
}

let parseTableOptions: {..} => result<tableOptions, string> = fieldJson => {
  switch dictGet(fieldJson, "tableOptions") {
  | None => Error("table field requires a \"tableOptions\" object")
  | Some(raw) => {
      let rowSelector: option<string> = dictGet(raw, "rowSelector")
      let columnsRaw: option<array<{..}>> = dictGet(raw, "columns")
      switch columnsRaw {
      | None => Error("table field requires \"tableOptions.columns\"")
      | Some(cols) if Array.length(cols) == 0 =>
        Error("table field requires at least one column in \"tableOptions.columns\"")
      | Some(cols) => {
          let parsedColumnsResult: result<array<columnField>, string> = cols->Array.reduce(Ok([]), (
            acc,
            colJson,
          ) => {
            switch acc {
            | Error(e) => Error(e)
            | Ok(parsedCols) =>
              switch parseColumnField(colJson) {
              | Error(e) => Error(e)
              | Ok(col) => {
                  parsedCols->Array.push(col)
                  Ok(parsedCols)
                }
              }
            }
          })

          switch parsedColumnsResult {
          | Error(e) => Error(e)
          | Ok(columns) => Ok({?rowSelector, columns})
          }
        }
      }
    }
  }
}
