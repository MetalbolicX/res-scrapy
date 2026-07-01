open Test
open Assertions
open FieldTypes

let collectStrings = (json: option<JSON.t>): array<string> => {
  switch json {
  | Some(j) =>
    let raw = NodeJsBinding.jsonStringify(j)
    let arr = TestHelpers.arrayFromJsonString(raw)
    arr->Array.map(node => NodeJsBinding.jsonStringify(node))
  | None => []
  }
}

let listJson = (opts: listOptions, els: array<NodeHtmlParserBinding.htmlElement>) =>
  switch ListExtractor.extract(els, opts) {
  | Some(j) => Some(j)
  | None => None
  }

test("ListExtractor ListText returns JSON array", () => {
  let doc = HtmlFixture.parse("<ul><li>A</li><li>B</li></ul>")
  let els = HtmlFixture.selectAll(doc, "li")
  let opts: listOptions = {itemType: ListText}
  isOptionEqualTo(
    Some(TestHelpers.jsonFromString("[\"A\",\"B\"]")),
    ListExtractor.extract(els, opts),
    ~eq=(a, b) => NodeJsBinding.jsonStringify(a) == NodeJsBinding.jsonStringify(b),
  )
})

test("ListExtractor supports unique, filter and limit", () => {
  let doc = HtmlFixture.parse("<ul><li>A</li><li>B</li><li>A</li><li>C</li></ul>")
  let els = HtmlFixture.selectAll(doc, "li")
  let opts: listOptions = {itemType: ListText, unique: true, filter: "^[AB]$", limit: 2}
  isOptionEqualTo(
    Some(TestHelpers.jsonFromString("[\"A\",\"B\"]")),
    ListExtractor.extract(els, opts),
    ~eq=(a, b) => NodeJsBinding.jsonStringify(a) == NodeJsBinding.jsonStringify(b),
  )
})

test("ListExtractor rejects unsafe regex patterns", () => {
  let doc = HtmlFixture.parse("<ul><li>A</li><li>B</li><li>C</li></ul>")
  let els = HtmlFixture.selectAll(doc, "li")
  let unsafeBackref: listOptions = {itemType: ListText, filter: "(a)\\1+"}
  let unsafeLookahead: listOptions = {itemType: ListText, filter: "(?=A)A"}
  let unsafeAlternation: listOptions = {itemType: ListText, filter: "(a|b)+"}

  isOptionEqualTo(
    Some(TestHelpers.jsonFromString("[]")),
    ListExtractor.extract(els, unsafeBackref),
    ~eq=(a, b) => NodeJsBinding.jsonStringify(a) == NodeJsBinding.jsonStringify(b),
  )
  isOptionEqualTo(
    Some(TestHelpers.jsonFromString("[]")),
    ListExtractor.extract(els, unsafeLookahead),
    ~eq=(a, b) => NodeJsBinding.jsonStringify(a) == NodeJsBinding.jsonStringify(b),
  )
  isOptionEqualTo(
    Some(TestHelpers.jsonFromString("[]")),
    ListExtractor.extract(els, unsafeAlternation),
    ~eq=(a, b) => NodeJsBinding.jsonStringify(a) == NodeJsBinding.jsonStringify(b),
  )
})

test("ListExtractor supports join output", () => {
  let doc = HtmlFixture.parse("<ul><li>A</li><li>B</li></ul>")
  let els = HtmlFixture.selectAll(doc, "li")
  let opts: listOptions = {itemType: ListText, join: "|"}
  isOptionEqualTo(
    Some(TestHelpers.jsonFromString("\"A|B\"")),
    ListExtractor.extract(els, opts),
    ~eq=(a, b) => NodeJsBinding.jsonStringify(a) == NodeJsBinding.jsonStringify(b),
  )
})

test("ListExtractor ListAttribute and ListUrl", () => {
  let doc = HtmlFixture.parse(
    "<a class='l' href='https://a.com' data-id='1'>A</a><a class='l' href='https://b.com' data-id='2'>B</a>",
  )
  let els = HtmlFixture.selectAll(doc, ".l")
  let attrOpts: listOptions = {itemType: ListAttribute("data-id")}
  let urlOpts: listOptions = {itemType: ListUrl}
  isOptionEqualTo(
    Some(TestHelpers.jsonFromString("[\"1\",\"2\"]")),
    ListExtractor.extract(els, attrOpts),
    ~eq=(a, b) => NodeJsBinding.jsonStringify(a) == NodeJsBinding.jsonStringify(b),
  )
  isOptionEqualTo(
    Some(TestHelpers.jsonFromString("[\"https://a.com/\",\"https://b.com/\"]")),
    ListExtractor.extract(els, urlOpts),
    ~eq=(a, b) => NodeJsBinding.jsonStringify(a) == NodeJsBinding.jsonStringify(b),
  )
})

/* ============================================================================
   Phase 3 PR 2b: Extractor Reuse — delegation contract
   These tests verify that ListText / ListAttribute / ListUrl itemTypes produce
   the same output as calling the corresponding individual extractor on the same
   element with list-level normalization applied (trim+filter-empty for text/
   attribute, extraction-as-is for url). Locks in the delegation pattern
   introduced by task 3.3.
   ============================================================================ */

/* listTrim mirrors the trim+filter that ListExtractor applies at the
 list-semantics layer for text and attribute item types. */
let listTrim = (s: string): option<string> => {
  let t = String.trim(s)
  if String.length(t) === 0 {
    None
  } else {
    Some(t)
  }
}

/* expectedItem computes what the list-extractor SHOULD return for one element
   for each itemType — i.e. the named extractor's output plus list-level
   normalization. This is the truth source used by the delegation tests. */
let expectedItem = (el: NodeHtmlParserBinding.htmlElement, itemType: listItemType): option<
  string,
> => {
  switch itemType {
  | ListText => TextExtractor.extract(el, None)
  | ListHtml => {
      let h = el.innerHTML
      if String.length(h) === 0 {
        None
      } else {
        Some(h)
      }
    }
  | ListAttribute(name) =>
    AttributeExtractor.extract(el, {names: [name], mode: First})->Option.flatMap(listTrim)
  | ListUrl => UrlExtractor.extract(el, None)
  }
}

let expectedForList = (
  itemType: listItemType,
  els: array<NodeHtmlParserBinding.htmlElement>,
): array<string> => {
  let len = Array.length(els)
  let acc: ref<array<string>> = ref([])
  if len > 0 {
    for i in 0 to len - 1 {
      let el = els->Array.get(i)
      switch el {
      | Some(e) =>
        switch expectedItem(e, itemType) {
        | Some(v) => acc := acc.contents->Array.concat([v])
        | None => ()
        }
      | None => ()
      }
    }
  }
  acc.contents
}

test("PR 2b ListText delegates to TextExtractor.extract on each element", () => {
  let doc = HtmlFixture.parse("<ul><li>  Alice  </li><li>Bob</li><li></li></ul>")
  let els = HtmlFixture.selectAll(doc, "li")
  let opts: listOptions = {itemType: ListText}

  let expected = expectedForList(ListText, els)
  let actual = collectStrings(listJson(opts, els))

  isIntEqualTo(expected->Array.length, actual->Array.length, ~message="ListText length")
  for i in 0 to expected->Array.length - 1 {
    let e = NodeJsBinding.jsonStringify(
      JSON.Encode.string(expected->Array.get(i)->Option.getOr("")),
    )
    isTextEqualTo(e, actual->Array.get(i)->Option.getOr(""))
  }
})

test("PR 2b ListAttribute delegates to AttributeExtractor.extract on each element", () => {
  let doc = HtmlFixture.parse(
    "<a class='l' href='https://a.com' data-id='1'>A</a><a class='l' href='https://b.com' data-id='2'>B</a>",
  )
  let els = HtmlFixture.selectAll(doc, ".l")
  let opts: listOptions = {itemType: ListAttribute("data-id")}

  let expected = expectedForList(ListAttribute("data-id"), els)
  let actual = collectStrings(listJson(opts, els))

  isIntEqualTo(expected->Array.length, actual->Array.length, ~message="ListAttr length")
  for i in 0 to expected->Array.length - 1 {
    let e = NodeJsBinding.jsonStringify(
      JSON.Encode.string(expected->Array.get(i)->Option.getOr("")),
    )
    isTextEqualTo(e, actual->Array.get(i)->Option.getOr(""))
  }
})

test("PR 2b ListUrl delegates to UrlExtractor.extract on each element", () => {
  let doc = HtmlFixture.parse(
    "<a class='l' href='https://a.com'>A</a><a class='l' href='https://b.com'>B</a>",
  )
  let els = HtmlFixture.selectAll(doc, ".l")
  let opts: listOptions = {itemType: ListUrl}

  let expected = expectedForList(ListUrl, els)
  let actual = collectStrings(listJson(opts, els))

  isIntEqualTo(expected->Array.length, actual->Array.length, ~message="ListUrl length")
  for i in 0 to expected->Array.length - 1 {
    let e = NodeJsBinding.jsonStringify(
      JSON.Encode.string(expected->Array.get(i)->Option.getOr("")),
    )
    isTextEqualTo(e, actual->Array.get(i)->Option.getOr(""))
  }
})

test("PR 2b ListText/Attribute/Url extractors source-of-truth unification", () => {
  // Lock the meta-contract: every itemType's value must come from the
  // named extractor (not a duplicated implementation).
  let doc = HtmlFixture.parse(
    "<ul><li class='t'> Hello </li></ul><a class='l' href='https://x.com' data-id='42'>X</a>",
  )
  let liEls = HtmlFixture.selectAll(doc, ".t")
  let aEls = HtmlFixture.selectAll(doc, ".l")

  let liOpt: listOptions = {itemType: ListText}
  let attrOpt: listOptions = {itemType: ListAttribute("data-id")}
  let urlOpt: listOptions = {itemType: ListUrl}

  let textVals = collectStrings(listJson(liOpt, liEls))
  let attrVals = collectStrings(listJson(attrOpt, aEls))
  let urlVals = collectStrings(listJson(urlOpt, aEls))

  isIntEqualTo(1, textVals->Array.length, ~message="text unification length")
  isIntEqualTo(1, attrVals->Array.length, ~message="attr unification length")
  isIntEqualTo(1, urlVals->Array.length, ~message="url unification length")
  isTextEqualTo("\"Hello\"", textVals->Array.get(0)->Option.getOr(""), ~message="text value")
  isTextEqualTo("\"42\"", attrVals->Array.get(0)->Option.getOr(""), ~message="attr value")
  isTextEqualTo("\"https://x.com/\"", urlVals->Array.get(0)->Option.getOr(""), ~message="url value")
})
