open FieldTypes

let extract: (NodeHtmlParserBinding.htmlElement, option<textOptions>) => option<string>
let extractJoined: (array<NodeHtmlParserBinding.htmlElement>, string, option<textOptions>) => option<string>
