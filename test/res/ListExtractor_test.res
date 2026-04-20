open Test
open Assertions
open FieldTypes

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
