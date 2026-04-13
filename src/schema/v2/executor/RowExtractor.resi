open FieldTypes

let run: (NodeHtmlParserBinding.htmlElement, schema) => result<JSON.t, schemaError>
module Strategy: ExtractionStrategy.S
