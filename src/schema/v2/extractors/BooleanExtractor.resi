open FieldTypes

let extract: (NodeHtmlParserBinding.htmlElement, option<booleanOptions>) => result<option<bool>, schemaError>
let extractPresence: bool => bool
let extractAttributeCheck: (NodeHtmlParserBinding.htmlElement, option<booleanOptions>) => option<bool>
