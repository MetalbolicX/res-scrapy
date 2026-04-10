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

test("HtmlExtractor returns innerHTML by default", () => {
  let doc = HtmlFixture.parse("<div class='box'><span>Hi</span></div>")
  let el = getElement(doc, ".box")
  isOptionEqualTo(Some("<span>Hi</span>"), HtmlExtractor.extract(el, None), ~eq=(a, b) => a == b)
})

test("HtmlExtractor supports outer mode", () => {
  let doc = HtmlFixture.parse("<div class='box'><span>Hi</span></div>")
  let el = getElement(doc, ".box")
  isOptionEqualTo(
    Some("<div class='box'><span>Hi</span></div>"),
    HtmlExtractor.extract(el, Some({mode: Outer})),
    ~eq=(a, b) => a == b,
  )
})

test("HtmlExtractor can strip script and style blocks", () => {
  let doc = HtmlFixture.parse(
    "<div class='box'><style>.x{}</style><span>Hi</span><script>1+1</script></div>",
  )
  let el = getElement(doc, ".box")
  isOptionEqualTo(
    Some("<span>Hi</span>"),
    HtmlExtractor.extract(el, Some({stripScripts: true, stripStyles: true})),
    ~eq=(a, b) => a == b,
  )
})
