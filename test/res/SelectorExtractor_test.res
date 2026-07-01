open Test
open Assertions
open ParseCli

let ctx = AppContext.production
let ops = NodeHtmlDocument.operations

test("SelectorExtractor Single mode returns one element with Text extract", () => {
  let doc = Document.parse(ops, "<div class='t'>Hello</div>")
  switch SelectorExtractor.extractElements(ctx, doc, ".t", Text, Single) {
  | Ok(arr) => {
      isIntEqualTo(1, Array.length(arr))
      isTextEqualTo("Hello", Option.getOr(arr[0], ""))
    }
  | Error(msg) => failWith(`Expected Ok but got Error: ${msg}`)
  }
})

test("SelectorExtractor Multiple mode returns all matches with Text extract", () => {
  let doc = Document.parse(ops, "<span>A</span><span>B</span><span>C</span>")
  switch SelectorExtractor.extractElements(ctx, doc, "span", Text, Multiple) {
  | Ok(arr) => {
      isIntEqualTo(3, Array.length(arr))
      isTextEqualTo("A", Option.getOr(arr[0], ""))
      isTextEqualTo("B", Option.getOr(arr[1], ""))
      isTextEqualTo("C", Option.getOr(arr[2], ""))
    }
  | Error(msg) => failWith(`Expected Ok but got Error: ${msg}`)
  }
})

test("SelectorExtractor Single mode with no match returns empty array", () => {
  let doc = Document.parse(ops, "<div>nope</div>")
  switch SelectorExtractor.extractElements(ctx, doc, ".missing", Text, Single) {
  | Ok(arr) => isIntEqualTo(0, Array.length(arr))
  | Error(msg) => failWith(`Expected Ok with empty array, got Error: ${msg}`)
  }
})

test("SelectorExtractor Multiple mode with no match returns empty array", () => {
  let doc = Document.parse(ops, "<div>nope</div>")
  switch SelectorExtractor.extractElements(ctx, doc, ".missing", Text, Multiple) {
  | Ok(arr) => isIntEqualTo(0, Array.length(arr))
  | Error(msg) => failWith(`Expected Ok with empty array, got Error: ${msg}`)
  }
})

test("SelectorExtractor OuterHtml extract contains the tag", () => {
  let doc = Document.parse(ops, "<div class='t'>Hello</div>")
  switch SelectorExtractor.extractElements(ctx, doc, ".t", OuterHtml, Single) {
  | Ok(arr) => {
      isIntEqualTo(1, Array.length(arr))
      isTruthy(%raw(`s => s.includes("<div")`)(Option.getOr(arr[0], "")))
      isTruthy(%raw(`s => s.includes("Hello")`)(Option.getOr(arr[0], "")))
    }
  | Error(msg) => failWith(`Expected Ok but got Error: ${msg}`)
  }
})

test("SelectorExtractor InnerHtml extract contains inner content", () => {
  let doc = Document.parse(ops, "<div class='t'>Hello</div>")
  switch SelectorExtractor.extractElements(ctx, doc, ".t", InnerHtml, Single) {
  | Ok(arr) => {
      isIntEqualTo(1, Array.length(arr))
      isTruthy(%raw(`s => s.includes("Hello")`)(Option.getOr(arr[0], "")))
      isTruthy(%raw(`s => !s.includes("<div")`)(Option.getOr(arr[0], "")))
    }
  | Error(msg) => failWith(`Expected Ok but got Error: ${msg}`)
  }
})

test("SelectorExtractor Attribute extract returns attribute value", () => {
  let doc = Document.parse(ops, "<a class='link' href='https://example.com'>x</a>")
  switch SelectorExtractor.extractElements(ctx, doc, ".link", Attribute("href"), Single) {
  | Ok(arr) => {
      isIntEqualTo(1, Array.length(arr))
      isTextEqualTo("https://example.com", Option.getOr(arr[0], ""))
    }
  | Error(msg) => failWith(`Expected Ok but got Error: ${msg}`)
  }
})

test("SelectorExtractor missing attribute returns empty string", () => {
  let doc = Document.parse(ops, "<a class='link'>x</a>")
  switch SelectorExtractor.extractElements(ctx, doc, ".link", Attribute("href"), Single) {
  | Ok(arr) => {
      isIntEqualTo(1, Array.length(arr))
      isTextEqualTo("", Option.getOr(arr[0], ""))
    }
  | Error(msg) => failWith(`Expected Ok but got Error: ${msg}`)
  }
})