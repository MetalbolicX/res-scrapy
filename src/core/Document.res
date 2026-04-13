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

let parse = (ops: operations, html: string) => ops.parse(html)
let querySelector = (ops: operations, doc: document, selector: string) => ops.querySelector(doc, selector)
let querySelectorAll = (ops: operations, doc: document, selector: string) =>
  ops.querySelectorAll(doc, selector)
let getAttribute = (ops: operations, el: element, name: string) => ops.getAttribute(el, name)
let textContent = (ops: operations, el: element) => ops.textContent(el)
let innerHTML = (ops: operations, el: element) => ops.innerHTML(el)
let outerHTML = (ops: operations, el: element) => ops.outerHTML(el)
let tagName = (ops: operations, el: element) => ops.tagName(el)
