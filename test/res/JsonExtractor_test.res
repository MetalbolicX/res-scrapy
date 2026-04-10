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

test("JsonExtractor parses JSON from text", () => {
  let doc = HtmlFixture.parse("<script class='j'>{\"a\":1,\"b\":2}</script>")
  let el = getElement(doc, ".j")
  isOptionEqualTo(
    Some(TestHelpers.jsonFromString("{\"a\":1,\"b\":2}")),
    JsonExtractor.extract(el, None),
    ~eq=(a, b) => NodeJsBinding.jsonStringify(a) == NodeJsBinding.jsonStringify(b),
  )
})

test("JsonExtractor parses JSON from attribute", () => {
  let doc = HtmlFixture.parse("<div class='j' data-json='{" ++ "\"a\":1" ++ "}'></div>")
  let el = getElement(doc, ".j")
  let opts: option<jsonOptions> = Some({source: "attribute", attribute: "data-json"})
  isOptionEqualTo(
    Some(TestHelpers.jsonFromString("{\"a\":1}")),
    JsonExtractor.extract(el, opts),
    ~eq=(a, b) => NodeJsBinding.jsonStringify(a) == NodeJsBinding.jsonStringify(b),
  )
})

test("JsonExtractor supports dot path", () => {
  let doc = HtmlFixture.parse("<script class='j'>{\"offer\":{\"price\":42}}</script>")
  let el = getElement(doc, ".j")
  isOptionEqualTo(
    Some(TestHelpers.jsonFromString("42")),
    JsonExtractor.extract(el, Some({path: "offer.price"})),
    ~eq=(a, b) => NodeJsBinding.jsonStringify(a) == NodeJsBinding.jsonStringify(b),
  )
})

test("JsonExtractor handles parse errors with onError policy", () => {
  let doc = HtmlFixture.parse("<script class='j'>not-json</script>")
  let el = getElement(doc, ".j")
  isOptionEqualTo(
    Some(TestHelpers.jsonFromString("\"not-json\"")),
    JsonExtractor.extract(el, Some({onError: ReturnText})),
    ~eq=(a, b) => NodeJsBinding.jsonStringify(a) == NodeJsBinding.jsonStringify(b),
  )
  isOptionEqualTo(None, JsonExtractor.extract(el, None), ~eq=(a, b) => NodeJsBinding.jsonStringify(a) == NodeJsBinding.jsonStringify(b))
})
