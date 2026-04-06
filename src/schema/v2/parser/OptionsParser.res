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
      Some({?mode})
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
// boolean options
// ---------------------------------------------------------------------------

let parseBooleanMode: string => booleanMode = s => switch s {
| "presence" => Presence
| "attributeCheck" => AttributeCheck
| _ => Mapping
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
      let onUnknown = dictGet(raw, "onUnknown")
      Some({?mode, ?trueValues, ?falseValues, ?attribute, ?onUnknown})
    }
  }
}
