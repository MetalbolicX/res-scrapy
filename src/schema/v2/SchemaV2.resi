open FieldTypes

let loadSchema: (~isInline: bool, string) => result<schema, schemaError>
let applySchema: (NodeHtmlParserBinding.htmlElement, schema) => result<JSON.t, schemaError>
