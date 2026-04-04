/** Public interface for Schema.res
  * Exposes the schema types and public function signatures.
  */
type fieldType =
  | Text
  | Attribute(string)
  | Html
  | Number
  | Boolean

type schemaField = {
  selector: string,
  fieldType: fieldType,
  required: bool,
  default: option<string>,
}

type schemaConfig = {
  ignoreErrors: bool,
  limit: int,
}

type schema = {
  name: option<string>,
  description: option<string>,
  fields: array<(string, schemaField)>,
  config: schemaConfig,
}

type schemaError =
  | InvalidJson(string)
  | MissingFields(string)
  | InvalidFieldType({field: string, got: string})
  | AttributeMissingKey(string)
  | FileReadError(string)
  | RequiredFieldMissing({fieldName: string, selector: string})

// let parseFieldType: (string, {..}) => result<fieldType, schemaError>
// let parseField: (string, {..}) => result<schemaField, schemaError>
// let parseSchema: string => result<schema, schemaError>
let loadSchema: (~isInline: bool, string) => result<schema, schemaError>

// let extractValue: (NodeHtmlParserBinding.htmlElement, fieldType) => JSON.t
let applySchema: (NodeHtmlParserBinding.htmlElement, schema) => result<JSON.t, schemaError>
