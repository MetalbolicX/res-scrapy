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

test("TextExtractor.extractJoined joins multiple elements with separator", () => {
  let doc = HtmlFixture.parse(`<div class='items'><span>Apple</span><span>Banana</span><span>Cherry</span></div>`)
  let els = HtmlFixture.selectAll(doc, "span")
  isIntEqualTo(3, Array.length(els))
  let result = TextExtractor.extractJoined(els, ", ", None)
  isOptionEqualTo(Some("Apple, Banana, Cherry"), result, ~eq=(a, b) => a == b)
})

test("TextExtractor.extractJoined applies options to each element", () => {
  let doc = HtmlFixture.parse(`<div class='items'><span>APPLE</span><span>banana</span></div>`)
  let els = HtmlFixture.selectAll(doc, "span")
  let result = TextExtractor.extractJoined(els, " | ", Some({lowercase: true}))
  isOptionEqualTo(Some("apple | banana"), result, ~eq=(a, b) => a == b)
})

test("TextExtractor.extractJoined with single element", () => {
  let doc = HtmlFixture.parse(`<div class='item'><span>Solo</span></div>`)
  let els = HtmlFixture.selectAll(doc, "span")
  isIntEqualTo(1, Array.length(els))
  let result = TextExtractor.extractJoined(els, ", ", None)
  isOptionEqualTo(Some("Solo"), result, ~eq=(a, b) => a == b)
})

test("TextExtractor.extractJoined returns None for empty array", () => {
  let doc = HtmlFixture.parse(`<div class='empty'></div>`)
  let els = HtmlFixture.selectAll(doc, "span")
  isIntEqualTo(0, Array.length(els))
  let result = TextExtractor.extractJoined(els, ", ", None)
  isOptionEqualTo(None, result, ~eq=(a, b) => a == b)
})

test("TextExtractor.extractJoined pattern extracts from each matching element", () => {
  let doc = HtmlFixture.parse(`<div class='items'><span>Valid</span><span class='pattern'>no-match</span><span>AlsoValid</span></div>`)
  let els = HtmlFixture.selectAll(doc, "span")
  isIntEqualTo(3, Array.length(els))
  let opts: option<textOptions> = Some({pattern: "Valid"})
  let result = TextExtractor.extractJoined(els, " | ", opts)
  isOptionEqualTo(Some("Valid | Valid"), result, ~eq=(a, b) => a == b)
})

test("TextExtractor.extractJoined with empty string separator", () => {
  let doc = HtmlFixture.parse(`<div class='chars'><span>A</span><span>B</span><span>C</span></div>`)
  let els = HtmlFixture.selectAll(doc, "span")
  let result = TextExtractor.extractJoined(els, "", None)
  isOptionEqualTo(Some("ABC"), result, ~eq=(a, b) => a == b)
})
