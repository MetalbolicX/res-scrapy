open Test
open Assertions

test("Document operations parse and query", () => {
  let ops = NodeHtmlDocument.operations
  let doc = Document.parse(ops, "<div class='x' data-id='42'>Hello</div>")
  switch Document.querySelector(ops, doc, ".x") {
  | Some(el) => {
      isTextEqualTo("Hello", Document.textContent(ops, el))
      isTextEqualTo("42", Document.getAttribute(ops, el, "data-id")->Option.getOr(""))
    }
  | None => failWith("Expected .x element")
  }
})

test("Document querySelectorAll returns all matches", () => {
  let ops = NodeHtmlDocument.operations
  let doc = Document.parse(ops, "<span class='i'>A</span><span class='i'>B</span>")
  let items = Document.querySelectorAll(ops, doc, ".i")
  isIntEqualTo(2, Array.length(items))
})
