let parse: string => NodeHtmlParserBinding.htmlElement = NodeHtmlParserBinding.parse

let select: (NodeHtmlParserBinding.htmlElement, string) => option<NodeHtmlParserBinding.htmlElement> = (
  document,
  selector,
) => NodeHtmlParserBinding.querySelector(document, selector)->Nullable.toOption

let selectAll: (
  NodeHtmlParserBinding.htmlElement,
  string,
) => array<NodeHtmlParserBinding.htmlElement> = (document, selector) =>
  NodeHtmlParserBinding.querySelectorAll(document, selector)
