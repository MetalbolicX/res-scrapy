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
  default?: string,
}

type schemaConfig = {
  ignoreErrors: bool,
  limit: int,
}

type schema = {
  name?: string,
  description?: string,
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

let loadSchema: (~isInline: bool, string) => result<schema, schemaError>
let applySchema: (NodeHtmlParserBinding.htmlElement, schema) => result<JSON.t, schemaError>
