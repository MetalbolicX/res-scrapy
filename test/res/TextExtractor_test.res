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

test("TextExtractor trims text by default", () => {
  let doc = HtmlFixture.parse("<div class='t'>  Hello  </div>")
  let el = getElement(doc, ".t")
  isOptionEqualTo(Some("Hello"), TextExtractor.extract(el, None), ~eq=(a, b) => a == b)
})

test("TextExtractor supports trim false", () => {
  let doc = HtmlFixture.parse("<div class='t'>  Hello  </div>")
  let el = getElement(doc, ".t")
  let opts: option<textOptions> = Some({trim: false})
  isOptionEqualTo(Some("  Hello  "), TextExtractor.extract(el, opts), ~eq=(a, b) => a == b)
})

test("TextExtractor supports lowercase and uppercase", () => {
  let doc = HtmlFixture.parse("<div class='t'>HeLLo</div>")
  let el = getElement(doc, ".t")
  isOptionEqualTo(
    Some("hello"),
    TextExtractor.extract(el, Some({lowercase: true})),
    ~eq=(a, b) => a == b,
  )
  isOptionEqualTo(
    Some("HELLO"),
    TextExtractor.extract(el, Some({uppercase: true})),
    ~eq=(a, b) => a == b,
  )
})

test("TextExtractor supports normalizeWhitespace", () => {
  let doc = HtmlFixture.parse("<div class='t'>  A\n\tB   C  </div>")
  let el = getElement(doc, ".t")
  isOptionEqualTo(
    Some("A B C"),
    TextExtractor.extract(el, Some({normalizeWhitespace: true})),
    ~eq=(a, b) => a == b,
  )
})

test("TextExtractor supports regex pattern extraction", () => {
  let doc = HtmlFixture.parse("<div class='t'>Price: $42.00</div>")
  let el = getElement(doc, ".t")
  isOptionEqualTo(
    Some("42.00"),
    TextExtractor.extract(el, Some({pattern: "([0-9]+\\.[0-9]+)"})),
    ~eq=(a, b) => a == b,
  )
})

test("TextExtractor returns None when pattern has no match", () => {
  let doc = HtmlFixture.parse("<div class='t'>Price: unknown</div>")
  let el = getElement(doc, ".t")
  isOptionEqualTo(None, TextExtractor.extract(el, Some({pattern: "([0-9]+\\.[0-9]+)"})), ~eq=(a, b) => a == b)
})
