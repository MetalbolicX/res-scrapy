/** Parse the top-level `config` block of a schema JSON. */
open FieldTypes
open JsonUtils
open OptionsParser

let defaultConfig: schemaConfig = {ignoreErrors: false, limit: 0}

let parseTextDefaults: {..} => textOptions = raw => {
  let trim = dictGet(raw, "trim")
  let normalizeWhitespace = dictGet(raw, "normalizeWhitespace")
  let lowercase = dictGet(raw, "lowercase")
  let uppercase = dictGet(raw, "uppercase")
  let pattern = dictGet(raw, "pattern")
  let join = dictGet(raw, "join")
  {?trim, ?normalizeWhitespace, ?lowercase, ?uppercase, ?pattern, ?join}
}

let parseHtmlDefaults: {..} => htmlOptions = raw => {
  let mode = switch dictGet(raw, "mode") {
  | Some("outer") => Some(Outer)
  | Some("inner") => Some(Inner)
  | Some(_) | None => None
  }
  let stripScripts = dictGet(raw, "stripScripts")
  let stripStyles = dictGet(raw, "stripStyles")
  {?mode, ?stripScripts, ?stripStyles}
}

let parseNumberDefaults: {..} => numberOptions = raw => {
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
  {?stripNonNumeric, ?pattern, ?thousandsSeparator, ?decimalSeparator, ?precision, ?allowNegative,
   ?onError}
}

let parseBooleanDefaults: {..} => booleanOptions = raw => {
  let mode = switch dictGet(raw, "mode") {
  | Some("presence") => Some(Presence)
  | Some("attributeCheck") => Some(AttributeCheck)
  | Some(_) => Some(Mapping)
  | None => None
  }
  let trueValues = dictGet(raw, "trueValues")
  let falseValues = dictGet(raw, "falseValues")
  let attribute = dictGet(raw, "attribute")
  let onUnknown = switch dictGet(raw, "onUnknown") {
  | Some(s) => Some(parseBooleanUnknownPolicy(s))
  | None => None
  }
  {?mode, ?trueValues, ?falseValues, ?attribute, ?onUnknown}
}

let parseDateDefaults: {..} => dateOptions = raw => {
  let formats = dictGet(raw, "formats")
  let timezone = dictGet(raw, "timezone")
  let output = switch dictGet(raw, "output") {
  | Some("iso8601") => Some(Iso8601)
  | Some("epoch") => Some(Epoch)
  | Some("epochMillis") => Some(EpochMillis)
  | Some("custom") => {
      let fmt = switch dictGet(raw, "outputFormat") {
      | Some(f) => f
      | None => "yyyy-MM-dd"
      }
      Some(Custom(fmt))
    }
  | Some(_) | None => None
  }
  let strict = dictGet(raw, "strict")
  let source = dictGet(raw, "source")
  let attribute = dictGet(raw, "attribute")
  {?formats, ?timezone, ?output, ?strict, ?source, ?attribute}
}

let parseUrlDefaults: {..} => urlOptions = raw => {
  let base = dictGet(raw, "base")
  let resolve = dictGet(raw, "resolve")
  let validate = dictGet(raw, "validate")
  let protocol = dictGet(raw, "protocol")
  let stripQuery = dictGet(raw, "stripQuery")
  let stripHash = dictGet(raw, "stripHash")
  let attribute = dictGet(raw, "attribute")
  {?base, ?resolve, ?validate, ?protocol, ?stripQuery, ?stripHash, ?attribute}
}

let parseCountDefaults: {..} => countOptions = raw => {
  let min = dictGet(raw, "min")
  let max = dictGet(raw, "max")
  {?min, ?max}
}

let parseJsonDefaults: {..} => jsonOptions = raw => {
  let source = dictGet(raw, "source")
  let attribute = dictGet(raw, "attribute")
  let path = dictGet(raw, "path")
  let onError = switch dictGet(raw, "onError") {
  | Some(s) => Some(parseErrorPolicy(s))
  | None => None
  }
  {?source, ?attribute, ?path, ?onError}
}

let parseDefaults: {..} => option<schemaDefaults> = schemaJson => {
  switch dictGet(schemaJson, "defaults") {
  | None => None
  | Some(raw) => {
      let text = switch dictGet(raw, "text") {
      | Some(textRaw) => Some(parseTextDefaults(textRaw))
      | None => None
      }
      let html = switch dictGet(raw, "html") {
      | Some(htmlRaw) => Some(parseHtmlDefaults(htmlRaw))
      | None => None
      }
      let number = switch dictGet(raw, "number") {
      | Some(numberRaw) => Some(parseNumberDefaults(numberRaw))
      | None => None
      }
      let boolean = switch dictGet(raw, "boolean") {
      | Some(booleanRaw) => Some(parseBooleanDefaults(booleanRaw))
      | None => None
      }
      let count = switch dictGet(raw, "count") {
      | Some(countRaw) => Some(parseCountDefaults(countRaw))
      | None => None
      }
      let json = switch dictGet(raw, "json") {
      | Some(jsonRaw) => Some(parseJsonDefaults(jsonRaw))
      | None => None
      }
      let datetime = switch dictGet(raw, "datetime") {
      | Some(dateRaw) => Some(parseDateDefaults(dateRaw))
      | None => None
      }
      let url = switch dictGet(raw, "url") {
      | Some(urlRaw) => Some(parseUrlDefaults(urlRaw))
      | None => None
      }
      Some({?text, ?html, ?number, ?boolean, ?count, ?json, ?datetime, ?url})
    }
  }
}

let parseConfig: {..} => schemaConfig = schemaJson => {
  switch dictGet(schemaJson, "config") {
  | None => defaultConfig
  | Some(raw) => {
      let ignoreErrors: bool = switch dictGet(raw, "ignoreErrors") {
      | Some(true) => true
      | _ => false
      }
      let limit: int =
        (dictGet(raw, "limit"): option<Nullable.t<int>>)
        ->Option.flatMap(n => n->Nullable.toOption)
        ->Option.getOr(0)
      let rowSelector: option<string> = dictGet(raw, "rowSelector")
      let defaults = parseDefaults(raw)
      switch defaults {
      | None => {ignoreErrors, limit, ?rowSelector}
      | Some(defaults) => {ignoreErrors, limit, ?rowSelector, defaults}
      }
    }
  }
}
