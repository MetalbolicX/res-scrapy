/** Schema v2 public API.
  * Provides loadSchema and applySchema that replace the v1 implementation.
  * All types come from FieldTypes.
  */
open FieldTypes

// ---------------------------------------------------------------------------
// Load from inline JSON string or file path
// ---------------------------------------------------------------------------

let loadSchemaFromString: string => result<schema, schemaError> = raw =>
  switch NodeJsBinding.jsonParse(raw) {
  | None => Error(InvalidJson("Schema is not valid JSON"))
  | Some(json) => SchemaParser.parseSchema(json)
  }

let loadSchema: (~isInline: bool, string) => result<schema, schemaError> = (~isInline, source) => {
  if isInline {
    loadSchemaFromString(source)
  } else {
    try {
      let raw = NodeJsBinding.Fs.readFileSync(source)
      loadSchemaFromString(raw)
    } catch {
    | exn => {
        let msg = switch exn->JsExn.fromException {
        | Some(jsExn) => jsExn->JsExn.message->Option.getOr("Unknown error")
        | None => "Unknown error"
        }
        Error(FileReadError(`Could not read schema file "${source}": ${msg}`))
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Apply
// ---------------------------------------------------------------------------

let applySchema: (
  NodeHtmlParserBinding.htmlElement,
  schema,
) => result<JSON.t, schemaError> = SchemaExecutor.applySchema
