open NodeHtmlParserBinding

let resolveHeaders: htmlElement => array<htmlElement>
let isFirstRowHeader: htmlElement => bool
let resolveRows: (htmlElement, option<string>) => array<htmlElement>
