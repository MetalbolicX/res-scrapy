open FieldTypes

let extractValue: (
  NodeHtmlParserBinding.htmlElement,
  fieldType,
  extractContext,
) => result<JSON.t, schemaError>
let extractValueList: (
  array<NodeHtmlParserBinding.htmlElement>,
  fieldType,
  extractContext,
) => result<JSON.t, schemaError>
let extractValueOrAbsent: (
  option<NodeHtmlParserBinding.htmlElement>,
  fieldType,
  option<JSON.t>,
  extractContext,
) => result<JSON.t, schemaError>
