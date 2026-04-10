open Test
open Assertions
open FieldTypes

let absFloat = n => n < 0.0 ? -.n : n
let eqFloat = (a, b) => absFloat(a -. b) <= 0.000001

let getElement = (doc, selector) =>
  switch HtmlFixture.select(doc, selector) {
  | Some(el) => el
  | None => {
      failWith(`Missing element for selector ${selector}`)
      doc
    }
  }

test("NumberExtractor parses plain numbers", () => {
  let doc = HtmlFixture.parse("<span class='n'>42</span>")
  let el = getElement(doc, ".n")
  isOptionEqualTo(Some(42.0), NumberExtractor.extract(el, None), ~eq=eqFloat)
})

test("NumberExtractor parses currency by default", () => {
  let doc = HtmlFixture.parse("<span class='n'>$19.99</span>")
  let el = getElement(doc, ".n")
  isOptionEqualTo(Some(19.99), NumberExtractor.extract(el, None), ~eq=eqFloat)
})

test("NumberExtractor supports separators and precision", () => {
  let doc = HtmlFixture.parse("<span class='n1'>1,234.56</span><span class='n2'>3.14159</span>")
  let n1 = getElement(doc, ".n1")
  let n2 = getElement(doc, ".n2")
  isOptionEqualTo(
    Some(1234.56),
    NumberExtractor.extract(n1, Some({thousandsSeparator: ","})),
    ~eq=eqFloat,
  )
  isOptionEqualTo(Some(3.14), NumberExtractor.extract(n2, Some({precision: 2})), ~eq=eqFloat)
})

test("NumberExtractor respects allowNegative false", () => {
  let doc = HtmlFixture.parse("<span class='n'>-10.5</span>")
  let el = getElement(doc, ".n")
  isOptionEqualTo(None, NumberExtractor.extract(el, Some({allowNegative: false})), ~eq=eqFloat)
})

test("NumberExtractor returns None for non numeric text", () => {
  let doc = HtmlFixture.parse("<span class='n'>abc</span>")
  let el = getElement(doc, ".n")
  isOptionEqualTo(None, NumberExtractor.extract(el, Some({stripNonNumeric: false})), ~eq=eqFloat)
})
