let operations: Document.operations = {
  parse: NodeHtmlParserBinding.parse,
  querySelector: (doc, selector) =>
    NodeHtmlParserBinding.querySelector(doc, selector)->Nullable.toOption,
  querySelectorAll: NodeHtmlParserBinding.querySelectorAll,
  getAttribute: (el, name) => NodeHtmlParserBinding.getAttribute(el, name)->Nullable.toOption,
  textContent: el => el.textContent,
  innerHTML: el => el.innerHTML,
  outerHTML: el => el.outerHTML,
  tagName: el => el.tagName,
}
