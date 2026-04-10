open Test
open Assertions
open FieldTypes

let getElement = (doc, selector) =>
  switch HtmlFixture.select(doc, selector) {
  | Some(el) => el
  | None => {
      failWith(`Missing element for selector ${selector}`)
      doc
    }
  }

test("AttributeExtractor First mode returns first attribute raw value", () => {
  let doc = HtmlFixture.parse("<a class='link' href='' title='Title'></a>")
  let el = getElement(doc, ".link")
  let cfg: attributeConfig = {names: ["href", "title"], mode: First}
  isOptionEqualTo(Some(""), AttributeExtractor.extract(el, cfg), ~eq=(a, b) => a == b)
})

test("AttributeExtractor FirstNonEmpty skips empty attributes", () => {
  let doc = HtmlFixture.parse("<a class='link' href='' data-url='https://example.com'></a>")
  let el = getElement(doc, ".link")
  let cfg: attributeConfig = {names: ["href", "data-url"], mode: FirstNonEmpty}
  isOptionEqualTo(Some("https://example.com"), AttributeExtractor.extract(el, cfg), ~eq=(a, b) => a == b)
})

test("AttributeExtractor Join mode concatenates values", () => {
  let doc = HtmlFixture.parse("<div class='e' data-a='A' data-b='B'></div>")
  let el = getElement(doc, ".e")
  let joinSep = Some("|")
  let cfg: attributeConfig = {names: ["data-a", "data-b"], mode: Join, ?joinSep}
  isOptionEqualTo(Some("A|B"), AttributeExtractor.extract(el, cfg), ~eq=(a, b) => a == b)
})

test("AttributeExtractor returns None when all attributes are missing", () => {
  let doc = HtmlFixture.parse("<div class='e'></div>")
  let el = getElement(doc, ".e")
  let cfg: attributeConfig = {names: ["data-a", "data-b"], mode: FirstNonEmpty}
  isOptionEqualTo(None, AttributeExtractor.extract(el, cfg), ~eq=(a, b) => a == b)
})
