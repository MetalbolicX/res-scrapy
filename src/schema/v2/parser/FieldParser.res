/** Parse a single schema field from its raw JSON object.
  * Delegates option-level parsing to OptionsParser.
  */

open FieldTypes
open JsonUtils

type parseFieldTypeVisitor<'a> = {
  text: 'a => result<fieldType, string>,
  html: 'a => result<fieldType, string>,
  number: 'a => result<fieldType, string>,
  boolean: 'a => result<fieldType, string>,
  count: 'a => result<fieldType, string>,
  url: 'a => result<fieldType, string>,
  json: 'a => result<fieldType, string>,
  datetime: 'a => result<fieldType, string>,
  list: 'a => result<fieldType, string>,
  table: 'a => result<fieldType, string>,
  attribute: 'a => result<fieldType, string>,
}

let parseFieldTypeVisitor: parseFieldTypeVisitor<{..}> = {
  text: fieldJson => Ok(Text(OptionsParser.parseTextOptions(fieldJson))),
  html: fieldJson => Ok(Html(OptionsParser.parseHtmlOptions(fieldJson))),
  number: fieldJson => Ok(Number(OptionsParser.parseNumberOptions(fieldJson))),
  boolean: fieldJson => Ok(Boolean(OptionsParser.parseBooleanOptions(fieldJson))),
  count: fieldJson => Ok(Count(OptionsParser.parseCountOptions(fieldJson))),
  url: fieldJson => Ok(Url(OptionsParser.parseUrlOptions(fieldJson))),
  json: fieldJson => Ok(Json(OptionsParser.parseJsonOptions(fieldJson))),
  datetime: fieldJson => Ok(DateTime(OptionsParser.parseDateOptions(fieldJson))),
  list: fieldJson => Ok(List(OptionsParser.parseListOptions(fieldJson))),
  table: fieldJson =>
    switch OptionsParser.parseTableOptions(fieldJson) {
    | Ok(opts) => Ok(Table(opts))
    | Error(msg) => Error(msg)
    },
  attribute: fieldJson =>
    switch OptionsParser.parseAttributeConfig(fieldJson) {
    | Some(cfg) => Ok(Attribute(cfg))
    | None => Error("attribute field requires an \"attribute\" or \"attributes\" key")
    },
}

let parseFieldTypeDispatch = (fieldJson: {..}, typeName: string): result<fieldType, string> => {
  switch typeName {
  | "text" => parseFieldTypeVisitor.text(fieldJson)
  | "html" => parseFieldTypeVisitor.html(fieldJson)
  | "number" => parseFieldTypeVisitor.number(fieldJson)
  | "boolean" | "bool" => parseFieldTypeVisitor.boolean(fieldJson)
  | "count" => parseFieldTypeVisitor.count(fieldJson)
  | "url" => parseFieldTypeVisitor.url(fieldJson)
  | "json" => parseFieldTypeVisitor.json(fieldJson)
  | "datetime" => parseFieldTypeVisitor.datetime(fieldJson)
  | "list" => parseFieldTypeVisitor.list(fieldJson)
  | "table" => parseFieldTypeVisitor.table(fieldJson)
  | "attribute" => parseFieldTypeVisitor.attribute(fieldJson)
  | other => Error(`Unknown type: "${other}"`)
  }
}

/** Map the `type` string + field JSON  → fieldType variant. */
let parseFieldType: ({..}, string) => result<fieldType, string> = (fieldJson, typeName) =>
  parseFieldTypeDispatch(fieldJson, typeName)

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
          let required: bool = (dictGet(fieldJson, "required"): option<bool>)->Option.getOr(false)
          let default: option<JSON.t> = dictGet(fieldJson, "default")
          Ok({selector, fieldType, required, ?default})
        }
      }
    }
  }
}
