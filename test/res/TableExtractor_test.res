open Test
open Assertions

let run = (~html, ~selector="table") => {
  let doc = HtmlFixture.parse(html)
  TableExtractor.extract(doc, selector)
}

test("TableExtractor extracts rows using thead headers and tbody rows", () => {
  let html =
    "<table class='products'><thead><tr><th>Name</th><th>Price</th></tr></thead><tbody><tr><td>A</td><td>10</td></tr><tr><td>B</td><td>20</td></tr></tbody></table>"
  switch run(~html, ~selector=".products") {
  | Ok(rows) =>
    isTextEqualTo(
      "[{\"Name\":\"A\",\"Price\":\"10\"},{\"Name\":\"B\",\"Price\":\"20\"}]",
      NodeJsBinding.jsonStringify(rows),
    )
  | Error(_) => failWith("Expected successful table extraction")
  }
})

test("TableExtractor falls back to first tr headers when thead is missing", () => {
  let html =
    "<table><tr><th>Name</th><th>Price</th></tr><tr><td>A</td><td>10</td></tr><tr><td>B</td><td>20</td></tr></table>"
  switch run(~html) {
  | Ok(rows) =>
    isTextEqualTo(
      "[{\"Name\":\"A\",\"Price\":\"10\"},{\"Name\":\"B\",\"Price\":\"20\"}]",
      NodeJsBinding.jsonStringify(rows),
    )
  | Error(_) => failWith("Expected fallback header extraction")
  }
})

test("TableExtractor uses col_N fallback for empty headers", () => {
  let html =
    "<table><thead><tr><th> </th><th>Price</th></tr></thead><tbody><tr><td>A</td><td>10</td></tr></tbody></table>"
  switch run(~html) {
  | Ok(rows) => isTextEqualTo("[{\"col_0\":\"A\",\"Price\":\"10\"}]", NodeJsBinding.jsonStringify(rows))
  | Error(_) => failWith("Expected col_N fallback header")
  }
})

test("TableExtractor trims header and cell text", () => {
  let html =
    "<table><thead><tr><th> Name </th><th> Price </th></tr></thead><tbody><tr><td>  A  </td><td>  10  </td></tr></tbody></table>"
  switch run(~html) {
  | Ok(rows) => isTextEqualTo("[{\"Name\":\"A\",\"Price\":\"10\"}]", NodeJsBinding.jsonStringify(rows))
  | Error(_) => failWith("Expected trimmed values")
  }
})

test("TableExtractor fills missing cells with empty string", () => {
  let html =
    "<table><thead><tr><th>Name</th><th>Price</th><th>Stock</th></tr></thead><tbody><tr><td>A</td><td>10</td></tr></tbody></table>"
  switch run(~html) {
  | Ok(rows) =>
    isTextEqualTo(
      "[{\"Name\":\"A\",\"Price\":\"10\",\"Stock\":\"\"}]",
      NodeJsBinding.jsonStringify(rows),
    )
  | Error(_) => failWith("Expected missing cell fallback")
  }
})

test("TableExtractor ignores extra td cells beyond headers", () => {
  let html =
    "<table><thead><tr><th>Name</th></tr></thead><tbody><tr><td>A</td><td>10</td></tr></tbody></table>"
  switch run(~html) {
  | Ok(rows) => isTextEqualTo("[{\"Name\":\"A\"}]", NodeJsBinding.jsonStringify(rows))
  | Error(_) => failWith("Expected extra cells ignored")
  }
})

test("TableExtractor prefers tbody rows when present", () => {
  let html =
    "<table><tr><th>Name</th></tr><tr><td>SHOULD_SKIP</td></tr><tbody><tr><td>A</td></tr></tbody></table>"
  switch run(~html) {
  | Ok(rows) => isTextEqualTo("[{\"Name\":\"A\"}]", NodeJsBinding.jsonStringify(rows))
  | Error(_) => failWith("Expected tbody precedence")
  }
})

test("TableExtractor returns empty rows when table has only header row", () => {
  let html = "<table><tr><th>Name</th><th>Price</th></tr></table>"
  switch run(~html) {
  | Ok(rows) => isTextEqualTo("[]", NodeJsBinding.jsonStringify(rows))
  | Error(_) => failWith("Expected empty result for header-only table")
  }
})

test("TableExtractor returns empty objects when no headers are found", () => {
  let html = "<table><tbody><tr><td>A</td><td>10</td></tr></tbody></table>"
  switch run(~html) {
  | Ok(rows) => isTextEqualTo("[{}]", NodeJsBinding.jsonStringify(rows))
  | Error(_) => failWith("Expected empty-object rows without headers")
  }
})

test("TableExtractor returns selector error when table is missing", () => {
  switch run(~html="<div>No table</div>", ~selector=".missing") {
  | Error(message) => isTextEqualTo("No element found for table selector \".missing\"", message)
  | Ok(_) => failWith("Expected table selector error")
  }
})

test("TableExtractor treats nested tables as plain text content", () => {
  let html =
    "<table><thead><tr><th>Name</th></tr></thead><tbody><tr><td>Outer<td>Inner<table><tr><td>nested cell</td></tr></table></td></tr></tbody></table>"
  switch run(~html) {
  | Ok(rows) => {
      let out = NodeJsBinding.jsonStringify(rows)
      isTruthy(TestHelpers.stringContains(out, "Outer"))
      isTruthy(TestHelpers.stringContains(out, "nested cell"))
    }
  | Error(_) => failWith("Expected nested table extraction")
  }
})

test("TableExtractor ignores td cells in thead header resolution", () => {
  let html =
    "<table><thead><tr><th>Name</th><td>IGNORE</td></tr></thead><tbody><tr><td>A</td><td>10</td></tr></tbody></table>"
  switch run(~html) {
  | Ok(rows) => isTextEqualTo("[{\"Name\":\"A\"}]", NodeJsBinding.jsonStringify(rows))
  | Error(_) => failWith("Expected td cells ignored in header")
  }
})

test("TableExtractor uses only th cells when first tr has mixed th and td", () => {
  let html =
    "<table><tr><th>Name</th><td>Price</td></tr><tr><td>A</td><td>10</td></tr></table>"
  switch run(~html) {
  | Ok(rows) =>
    isTextEqualTo(
      "[{\"Name\":\"A\"}]",
      NodeJsBinding.jsonStringify(rows),
    )
  | Error(_) => failWith("Expected th-only header fallback")
  }
})

test("TableExtractor duplicate header names cause later columns to win", () => {
  let html =
    "<table><thead><tr><th>Name</th><th>Name</th></tr></thead><tbody><tr><td>A</td><td>B</td></tr></tbody></table>"
  switch run(~html) {
  | Ok(rows) =>
    isTextEqualTo("[{\"Name\":\"B\"}]", NodeJsBinding.jsonStringify(rows))
  | Error(_) => failWith("Expected later duplicate header to overwrite")
  }
})

test("TableExtractor treats colspan as a single plain cell", () => {
  let html =
    "<table><thead><tr><th>Name</th><th>Price</th></tr></thead><tbody><tr><td colspan=\"2\">wide</td></tr></tbody></table>"
  switch run(~html) {
  | Ok(rows) =>
    isTextEqualTo(
      "[{\"Name\":\"wide\",\"Price\":\"\"}]",
      NodeJsBinding.jsonStringify(rows),
    )
  | Error(_) => failWith("Expected colspan treated as single cell")
  }
})

test("TableExtractor treats rowspan as a single plain cell", () => {
  let html =
    "<table><thead><tr><th>Name</th><th>Price</th></tr></thead><tbody><tr><td rowspan=\"2\">tall</td><td>10</td></tr><tr><td>20</td></tr></tbody></table>"
  switch run(~html) {
  | Ok(rows) =>
    isTextEqualTo(
      "[{\"Name\":\"tall\",\"Price\":\"10\"},{\"Name\":\"20\",\"Price\":\"\"}]",
      NodeJsBinding.jsonStringify(rows),
    )
  | Error(_) => failWith("Expected rowspan treated as single cell")
  }
})

test("TableExtractor handles table with no thead and no th cells at all", () => {
  let html = "<table><tr><td>Name</td><td>Price</td></tr><tr><td>A</td><td>10</td></tr></table>"
  switch run(~html) {
  | Ok(rows) => isTextEqualTo("[{}]", NodeJsBinding.jsonStringify(rows))
  | Error(_) => failWith("Expected no-headers table to produce empty objects")
  }
})

test("TableExtractor handles tbody with all-whitespace td cells", () => {
  let html =
    "<table><thead><tr><th>Name</th></tr></thead><tbody><tr><td>   </td></tr></tbody></table>"
  switch run(~html) {
  | Ok(rows) => isTextEqualTo("[{\"Name\":\"\"}]", NodeJsBinding.jsonStringify(rows))
  | Error(_) => failWith("Expected whitespace td trimmed to empty")
  }
})

test("TableExtractor handles multiple tbody sections", () => {
  let html =
    "<table><thead><tr><th>Name</th></tr></thead><tbody><tr><td>A</td></tr></tbody><tbody><tr><td>B</td></tr></tbody></table>"
  switch run(~html) {
  | Ok(rows) => isTextEqualTo("[{\"Name\":\"A\"},{\"Name\":\"B\"}]", NodeJsBinding.jsonStringify(rows))
  | Error(_) => failWith("Expected multiple tbody rows combined")
  }
})

test("TableExtractor handles tr with no td cells", () => {
  let html =
    "<table><thead><tr><th>Name</th></tr></thead><tbody><tr></tr></tbody></table>"
  switch run(~html) {
  | Ok(rows) => isTextEqualTo("[{\"Name\":\"\"}]", NodeJsBinding.jsonStringify(rows))
  | Error(_) => failWith("Expected empty tr cell to produce empty string")
  }
})

test("TableExtractor handles empty thead and empty tbody", () => {
  let html = "<table><thead></thead><tbody></tbody></table>"
  switch run(~html) {
  | Ok(rows) => isTextEqualTo("[]", NodeJsBinding.jsonStringify(rows))
  | Error(_) => failWith("Expected empty table sections to produce empty array")
  }
})

test("TableExtractor handles table with only empty tr elements", () => {
  let html = "<table><tr></tr><tr></tr></table>"
  switch run(~html) {
  | Ok(rows) => isTextEqualTo("[{}]", NodeJsBinding.jsonStringify(rows))
  | Error(_) => failWith("Expected table with only empty rows")
  }
})

test("TableExtractor handles deeply nested tr and td structures", () => {
  let html =
    "<table><thead><tr><th>Name</th></tr></thead><tbody><tr><td><div><span><strong>Bold</strong></span></div></td></tr></tbody></table>"
  switch run(~html) {
  | Ok(rows) =>
    isTextEqualTo("[{\"Name\":\"Bold\"}]", NodeJsBinding.jsonStringify(rows))
  | Error(_) => failWith("Expected nested element text extraction")
  }
})
