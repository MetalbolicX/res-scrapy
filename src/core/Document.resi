type document = NodeHtmlParserBinding.htmlElement
type element = NodeHtmlParserBinding.htmlElement

type operations = {
  parse: string => document,
  querySelector: (document, string) => option<element>,
  querySelectorAll: (document, string) => array<element>,
  getAttribute: (element, string) => option<string>,
  textContent: element => string,
  innerHTML: element => string,
  outerHTML: element => string,
  tagName: element => string,
}

let parse: (operations, string) => document
let querySelector: (operations, document, string) => option<element>
let querySelectorAll: (operations, document, string) => array<element>
let getAttribute: (operations, element, string) => option<string>
let textContent: (operations, element) => string
let innerHTML: (operations, element) => string
let outerHTML: (operations, element) => string
let tagName: (operations, element) => string
