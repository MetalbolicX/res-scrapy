type htmlElement = {
  textContent: string,
  outerHTML: string,
  innerHTML: string,
  tagName: string,
}
@module("node-html-parser") external parse: string => htmlElement = "parse"
@send external querySelectorAll: (htmlElement, string) => array<htmlElement> = "querySelectorAll"
@send external querySelector: (htmlElement, string) => htmlElement = "querySelector"
