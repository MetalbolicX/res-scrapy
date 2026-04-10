open Test
open Assertions

test("CountExtractor returns number of matched elements", () => {
  let doc = HtmlFixture.parse("<ul><li>A</li><li>B</li><li>C</li></ul>")
  let items = HtmlFixture.selectAll(doc, "li")
  isOptionEqualTo(Some(3), CountExtractor.extract(items, None), ~eq=(a, b) => a == b)
})

test("CountExtractor returns zero for empty arrays", () => {
  let doc = HtmlFixture.parse("<div></div>")
  let items = HtmlFixture.selectAll(doc, "li")
  isOptionEqualTo(Some(0), CountExtractor.extract(items, None), ~eq=(a, b) => a == b)
})
