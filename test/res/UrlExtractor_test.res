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

test("UrlExtractor uses default href/src attributes", () => {
  let doc = HtmlFixture.parse(
    "<a class='a' href='https://example.com/a'></a><img class='i' src='https://example.com/i.png' />",
  )
  let a = getElement(doc, ".a")
  let i = getElement(doc, ".i")
  isOptionEqualTo(Some("https://example.com/a"), UrlExtractor.extract(a, None), ~eq=(a, b) => a == b)
  isOptionEqualTo(Some("https://example.com/i.png"), UrlExtractor.extract(i, None), ~eq=(a, b) => a == b)
})

test("UrlExtractor resolves relative URLs with base", () => {
  let doc = HtmlFixture.parse("<a class='a' href='/docs?a=1#intro'></a>")
  let a = getElement(doc, ".a")
  let opts: option<urlOptions> = Some({base: "https://example.com"})
  isOptionEqualTo(
    Some("https://example.com/docs?a=1#intro"),
    UrlExtractor.extract(a, opts),
    ~eq=(a, b) => a == b,
  )
})

test("UrlExtractor validates protocol and strips query/hash", () => {
  let doc = HtmlFixture.parse("<a class='a' href='https://example.com/docs?a=1#intro'></a>")
  let a = getElement(doc, ".a")
  let opts: option<urlOptions> = Some({protocol: "https", stripQuery: true, stripHash: true})
  isOptionEqualTo(Some("https://example.com/docs"), UrlExtractor.extract(a, opts), ~eq=(a, b) => a == b)
  isOptionEqualTo(None, UrlExtractor.extract(a, Some({protocol: "http"})), ~eq=(a, b) => a == b)
})

test("UrlExtractor returns None for missing or invalid URL", () => {
  let doc = HtmlFixture.parse(
    "<a class='a'></a><a class='b' href='::invalid::'></a><a class='c' href='javascript:alert(1)'></a>",
  )
  let a = getElement(doc, ".a")
  let b = getElement(doc, ".b")
  let c = getElement(doc, ".c")
  isOptionEqualTo(None, UrlExtractor.extract(a, None), ~eq=(a, b) => a == b)
  isOptionEqualTo(None, UrlExtractor.extract(b, None), ~eq=(a, b) => a == b)
  isOptionEqualTo(None, UrlExtractor.extract(c, None), ~eq=(a, b) => a == b)
})
