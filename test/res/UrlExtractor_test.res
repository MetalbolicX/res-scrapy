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

test("disabled URL validation returns raw parse failures only", () => {
  ["not a url", "/relative?p=1#h"]->Array.forEach(raw => {
    let el = HtmlFixture.parse(`<a href='${raw}'></a>`)->getElement("a")
    isOptionEqualTo(
      Some(raw),
      UrlExtractor.extract(el, Some({validate: false, stripQuery: true, stripHash: true})),
      ~eq=(a, b) => a == b,
    )
    isOptionEqualTo(None, UrlExtractor.extract(el, None), ~eq=(a, b) => a == b)
    isOptionEqualTo(None, UrlExtractor.extract(el, Some({validate: true})), ~eq=(a, b) => a == b)
  })
  [
    "<a></a>",
    "<a href=''></a>",
    "<a href='javascript:alert(1)'></a>",
    "<a href='data:text/plain,x'></a>",
  ]->Array.forEach(html => {
    isOptionEqualTo(
      None,
      UrlExtractor.extract(HtmlFixture.parse(html)->getElement("a"), Some({validate: false})),
      ~eq=(a, b) => a == b,
    )
  })
  let valid = HtmlFixture.parse("<a href='https://EXAMPLE.com/a?p=1#h'></a>")->getElement("a")
  isOptionEqualTo(
    Some("https://example.com/a"),
    UrlExtractor.extract(valid, Some({validate: false, stripQuery: true, stripHash: true})),
    ~eq=(a, b) => a == b,
  )
  isOptionEqualTo(
    None,
    UrlExtractor.extract(valid, Some({validate: false, protocol: "http"})),
    ~eq=(a, b) => a == b,
  )
  let relative = HtmlFixture.parse("<a href='/a?p=1#h'></a>")->getElement("a")
  isOptionEqualTo(
    Some("https://example.com/a?p=1#h"),
    UrlExtractor.extract(relative, Some({validate: false, base: "https://example.com"})),
    ~eq=(a, b) => a == b,
  )
})

test("disabled URL validation rejects unsafe schemes and keeps unparsed raw values", () => {
  let extract = (href, opts) =>
    HtmlFixture.parse(`<a href='${href}'></a>`)->getElement("a")->UrlExtractor.extract(opts)
  // Parsed unsafe schemes are rejected even with validate: false.
  isOptionEqualTo(None, extract("ftp://example.com/x", Some({validate: false})), ~eq=(a, b) =>
    a == b
  )
  // A protocol-relative URL has no base to resolve against, so parsing fails
  // and the raw attribute is returned byte-for-byte.
  isOptionEqualTo(
    Some("//cdn.example.com/a.js"),
    extract("//cdn.example.com/a.js", Some({validate: false})),
    ~eq=(a, b) => a == b,
  )
  // With a base it parses and resolves like any relative URL.
  isOptionEqualTo(
    Some("https://cdn.example.com/a.js"),
    extract("//cdn.example.com/a.js", Some({validate: false, base: "https://example.com"})),
    ~eq=(a, b) => a == b,
  )
})

test("UrlExtractor uses default href/src attributes", () => {
  let doc = HtmlFixture.parse(
    "<a class='a' href='https://example.com/a'></a><img class='i' src='https://example.com/i.png' />",
  )
  let a = getElement(doc, ".a")
  let i = getElement(doc, ".i")
  isOptionEqualTo(Some("https://example.com/a"), UrlExtractor.extract(a, None), ~eq=(a, b) =>
    a == b
  )
  isOptionEqualTo(Some("https://example.com/i.png"), UrlExtractor.extract(i, None), ~eq=(a, b) =>
    a == b
  )
})

test("UrlExtractor resolves relative URLs with base", () => {
  let doc = HtmlFixture.parse("<a class='a' href='/docs?a=1#intro'></a>")
  let a = getElement(doc, ".a")
  let opts: option<urlOptions> = Some({base: "https://example.com"})
  isOptionEqualTo(Some("https://example.com/docs?a=1#intro"), UrlExtractor.extract(a, opts), ~eq=(
    a,
    b,
  ) => a == b)
})

test("UrlExtractor validates protocol and strips query/hash", () => {
  let doc = HtmlFixture.parse("<a class='a' href='https://example.com/docs?a=1#intro'></a>")
  let a = getElement(doc, ".a")
  let opts: option<urlOptions> = Some({protocol: "https", stripQuery: true, stripHash: true})
  isOptionEqualTo(Some("https://example.com/docs"), UrlExtractor.extract(a, opts), ~eq=(a, b) =>
    a == b
  )
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
