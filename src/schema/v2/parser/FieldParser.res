/** Parse a single schema field from its raw JSON object.
  * Delegates option-level parsing to OptionsParser.
  */

open FieldTypes

@get_index external dictGet: ({..}, string) => option<'a> = ""

/** Map the `type` string + field JSON  → fieldType variant. */
let parseFieldType: ({..}, string) => result<fieldType, string> = (fieldJson, typeName) => {
  switch typeName {
  | "text" => Ok(Text(OptionsParser.parseTextOptions(fieldJson)))
  | "html" => Ok(Html(OptionsParser.parseHtmlOptions(fieldJson)))
  | "number" => Ok(Number(OptionsParser.parseNumberOptions(fieldJson)))
  | "boolean" | "bool" => Ok(Boolean(OptionsParser.parseBooleanOptions(fieldJson)))
  | "count" => Ok(Count(OptionsParser.parseCountOptions(fieldJson)))
  | "url" => Ok(Url(OptionsParser.parseUrlOptions(fieldJson)))
  | "json" => Ok(Json(OptionsParser.parseJsonOptions(fieldJson)))
  | "datetime" => Ok(DateTime(OptionsParser.parseDateOptions(fieldJson)))
  | "list" => Ok(List(OptionsParser.parseListOptions(fieldJson)))
  | "attribute" =>
    switch OptionsParser.parseAttributeConfig(fieldJson) {
    | Some(cfg) => Ok(Attribute(cfg))
    | None => Error("attribute field requires an \"attribute\" or \"attributes\" key")
    }
  | other => Error(`Unknown type: "${other}"`)
  }
}

/** Parse one field JSON object into a schemaField. */
let parseField: ({..}, string) => result<schemaField, schemaError> = (fieldJson, fieldName) => {
  switch dictGet(fieldJson, "selector") {
  | None =>
    Error(MissingFields(`Field "${fieldName}" is missing required key "selector"`))
  | Some(selector) => {
      let rawType: string = switch dictGet(fieldJson, "type") {
      | Some(t) => t
      | None => "text"
      }
      switch parseFieldType(fieldJson, rawType) {
      | Error(msg) => Error(InvalidFieldType({field: fieldName, got: msg}))
      | Ok(fieldType) => {
          let required: bool = switch dictGet(fieldJson, "required") {
          | Some(false) => false
          | _ => true
          }
          let default: option<string> = dictGet(fieldJson, "default")
          Ok({selector, fieldType, required, ?default})
        }
      }
    }
  }
}
