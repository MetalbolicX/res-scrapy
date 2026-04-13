type htmlElement = {
  textContent: string,
  outerHTML: string,
  innerHTML: string,
  tagName: string,
}

let parse: string => htmlElement
let querySelectorAll: (htmlElement, string) => array<htmlElement>
let querySelector: (htmlElement, string) => Nullable.t<htmlElement>
let getAttribute: (htmlElement, string) => Nullable.t<string>
