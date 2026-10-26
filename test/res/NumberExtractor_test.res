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

[
  ("1e5", Some(100000.0)),
  ("1.5E-3", Some(0.0015)),
  ("-2e3", Some(-2000.0)),
  ("2e+3", Some(2000.0)),
  ("5 items each", Some(5.0)),
  ("45%", Some(45.0)),
  ("3,14", Some(314.0)),
  ("", None),
  ("-", None),
  ("1e", Some(1.0)),
  ("e5", Some(5.0)),
  ("$1,234.50", Some(1234.5)),
  ("1.2.3", Some(1.2)),
  ("-$5", Some(-5.0)),
  ("1 e5", Some(15.0)),
  ("1e +3", Some(13.0)),
  ("1e+ 3", Some(13.0)),
  ("1+2", Some(12.0)),
]->Array.forEach(((input, expected)) => {
  test(`NumberExtractor default cleanup: ${input}`, () => {
    let doc = HtmlFixture.parse(`<span class='n'>${input}</span>`)
    isOptionEqualTo(expected, NumberExtractor.extract(getElement(doc, ".n"), None), ~eq=eqFloat)
  })
})

test("NumberExtractor scientific notation respects options", () => {
  let doc = HtmlFixture.parse(
    "<span class='comma'>3,14</span><span class='sci'>2e+3</span><span class='neg'>-2e3</span>",
  )
  isOptionEqualTo(
    Some(3.14),
    NumberExtractor.extract(getElement(doc, ".comma"), Some({decimalSeparator: ","})),
    ~eq=eqFloat,
  )
  isOptionEqualTo(
    Some(2000.0),
    NumberExtractor.extract(getElement(doc, ".sci"), Some({stripNonNumeric: false})),
    ~eq=eqFloat,
  )
  isOptionEqualTo(
    None,
    NumberExtractor.extract(getElement(doc, ".neg"), Some({allowNegative: false})),
    ~eq=eqFloat,
  )
})

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
