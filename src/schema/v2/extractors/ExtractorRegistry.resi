open FieldTypes

let extractValue: (NodeHtmlParserBinding.htmlElement, fieldType, option<schemaDefaults>) => result<JSON.t, schemaError>
let extractValueList: (array<NodeHtmlParserBinding.htmlElement>, fieldType, option<schemaDefaults>) => result<JSON.t, schemaError>
let extractValueOrAbsent: (option<NodeHtmlParserBinding.htmlElement>, fieldType, option<schemaDefaults>) => result<JSON.t, schemaError>
