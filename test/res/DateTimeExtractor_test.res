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

test("DateTimeExtractor parses ISO text by default", () => {
  let doc = HtmlFixture.parse("<time class='t'>2024-06-01T12:34:56Z</time>")
  let el = getElement(doc, ".t")
  isOptionEqualTo(
    Some("2024-06-01T12:34:56Z"),
    DateTimeExtractor.extract(el, None),
    ~eq=(a, b) => a == b,
  )
})

test("DateTimeExtractor supports attribute source", () => {
  let doc = HtmlFixture.parse("<time class='t' datetime='2024-06-01T12:34:56Z'>ignore</time>")
  let el = getElement(doc, ".t")
  let opts: option<dateOptions> = Some({source: "attribute", attribute: "datetime"})
  isOptionEqualTo(
    Some("2024-06-01T12:34:56Z"),
    DateTimeExtractor.extract(el, opts),
    ~eq=(a, b) => a == b,
  )
})

test("DateTimeExtractor supports custom parsing format", () => {
  let doc = HtmlFixture.parse("<time class='t'>06/01/2024</time>")
  let el = getElement(doc, ".t")
  let opts: option<dateOptions> = Some({formats: ["MM/dd/yyyy"], output: Custom("yyyy-MM-dd")})
  isOptionEqualTo(Some("2024-06-01"), DateTimeExtractor.extract(el, opts), ~eq=(a, b) => a == b)
})

test("DateTimeExtractor supports epoch outputs", () => {
  let doc = HtmlFixture.parse("<time class='t'>2024-06-01T00:00:00Z</time>")
  let el = getElement(doc, ".t")
  isOptionEqualTo(
    Some("1717200000"),
    DateTimeExtractor.extract(el, Some({output: Epoch})),
    ~eq=(a, b) => a == b,
  )
  isOptionEqualTo(
    Some("1717200000000"),
    DateTimeExtractor.extract(el, Some({output: EpochMillis})),
    ~eq=(a, b) => a == b,
  )
})

test("DateTimeExtractor returns None for empty and invalid values", () => {
  let doc = HtmlFixture.parse("<time class='a'></time><time class='b'>nope</time>")
  let a = getElement(doc, ".a")
  let b = getElement(doc, ".b")
  isOptionEqualTo(None, DateTimeExtractor.extract(a, None), ~eq=(a, b) => a == b)
  isOptionEqualTo(None, DateTimeExtractor.extract(b, None), ~eq=(a, b) => a == b)
})
