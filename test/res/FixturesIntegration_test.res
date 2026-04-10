open Test
open Assertions

let runFixture = (~html: string, ~schema: string) => {
  let doc = HtmlFixture.parse(html)
  switch SchemaV2.loadSchema(~isInline=true, schema) {
  | Ok(parsedSchema) => SchemaV2.applySchema(doc, parsedSchema)
  | Error(e) => Error(e)
  }
}

test("fixtures: attributes case", () => {
  let html =
    "<img class='lazy' data-lazy='lazy-image.jpg' data-src='fallback-image.jpg' src='actual-image.jpg' />"
    ++ "<a class='link' href='/foo' title='Foo Link' data-track='abc'>Foo</a>"
    ++ "<a class='all-attrs' href='/bar' title='Bar Link' rel='nofollow'>Bar</a>"
  let schema =
    "{\"fields\":{"
    ++ "\"imageSrcFallback\":{\"selector\":\"img.lazy\",\"type\":\"attribute\",\"attributes\":[\"data-lazy\",\"data-src\",\"src\"],\"attrMode\":\"firstNonEmpty\"},"
    ++ "\"linkHref\":{\"selector\":\"a.link\",\"type\":\"attribute\",\"attribute\":\"href\"},"
    ++ "\"allLinkAttrs\":{\"selector\":\"a.all-attrs\",\"type\":\"attribute\",\"attributes\":[\"href\",\"title\",\"rel\"],\"attrMode\":\"all\"},"
    ++ "\"joinedAttrs\":{\"selector\":\"a.all-attrs\",\"type\":\"attribute\",\"attributes\":[\"href\",\"title\",\"rel\"],\"attrMode\":\"join\"}"
    ++ "}}"
  switch runFixture(~html, ~schema) {
  | Ok(value) => {
      let out = NodeJsBinding.jsonStringify(value)
      isTruthy(TestHelpers.stringContains(out, "lazy-image.jpg"))
      isTruthy(TestHelpers.stringContains(out, "/foo"))
    }
  | Error(_) => failWith("attributes fixture should parse")
  }
})

test("fixtures: dates case", () => {
  let html =
    "<time class='iso' datetime='2024-06-01'>June 1, 2024</time><span class='long'>June 1, 2024</span><span class='us'>06/01/2024</span><span class='euro'>01-06-2024</span>"
  let schema =
    "{\"fields\":{"
    ++ "\"iso\":{\"selector\":\"time.iso\",\"type\":\"datetime\",\"dateOptions\":{\"source\":\"attribute\",\"attribute\":\"datetime\",\"output\":\"iso8601\"}},"
    ++ "\"longFormat\":{\"selector\":\".long\",\"type\":\"datetime\",\"dateOptions\":{\"formats\":[\"MMMM d, yyyy\"],\"output\":\"iso8601\"}},"
    ++ "\"us\":{\"selector\":\".us\",\"type\":\"datetime\",\"dateOptions\":{\"formats\":[\"MM/dd/yyyy\"],\"output\":\"iso8601\"}},"
    ++ "\"euro\":{\"selector\":\".euro\",\"type\":\"datetime\",\"dateOptions\":{\"formats\":[\"dd-MM-yyyy\"],\"output\":\"iso8601\"}}"
    ++ "}}"
  switch runFixture(~html, ~schema) {
  | Ok(value) => {
      let out = NodeJsBinding.jsonStringify(value)
      isTruthy(TestHelpers.stringContains(out, "2024-06-01T00:00:00Z"))
    }
  | Error(_) => failWith("dates fixture should parse")
  }
})

test("fixtures: inner_outer case", () => {
  let html =
    "<div class='card' id='card-1'><h2 class='title'>Card One</h2><div class='body'><p>First <strong>bold</strong></p><script>bad()</script><style>.x{}</style></div></div>"
  let schema =
    "{\"fields\":{"
    ++ "\"firstCardOuter\":{\"selector\":\"#card-1\",\"type\":\"html\",\"htmlOptions\":{\"mode\":\"outer\"}},"
    ++ "\"firstTitleText\":{\"selector\":\"#card-1 .title\",\"type\":\"text\"},"
    ++ "\"bodyClean\":{\"selector\":\"#card-1 .body\",\"type\":\"html\",\"htmlOptions\":{\"mode\":\"inner\",\"stripScripts\":true,\"stripStyles\":true}}"
    ++ "}}"
  switch runFixture(~html, ~schema) {
  | Ok(value) => {
      let out = NodeJsBinding.jsonStringify(value)
      isTruthy(TestHelpers.stringContains(out, "Card One"))
      isTruthy(TestHelpers.stringContains(out, "First"))
    }
  | Error(_) => failWith("inner_outer fixture should parse")
  }
})

test("fixtures: other case", () => {
  let html =
    "<div class='product'><span class='price'>$1,234.56</span><span class='discount'>25% OFF</span><span class='feat'>fast</span><span class='feat'>cheap</span><span class='feat'>cheap</span><span class='available'>In Stock</span><script type='application/ld+json'>{\"offers\":{\"price\":\"19.99\"}}</script></div>"
  let schema =
    "{\"fields\":{"
    ++ "\"price\":{\"selector\":\".product .price\",\"type\":\"number\",\"numberOptions\":{\"stripNonNumeric\":true,\"pattern\":\"([0-9,\\\\.]+)\",\"precision\":2}},"
    ++ "\"discount\":{\"selector\":\".product .discount\",\"type\":\"number\",\"numberOptions\":{\"pattern\":\"([0-9\\\\.]+)%\"}},"
    ++ "\"features\":{\"selector\":\".product .feat\",\"type\":\"list\",\"listOptions\":{\"itemType\":\"text\",\"unique\":true}},"
    ++ "\"available\":{\"selector\":\".product .available\",\"type\":\"boolean\",\"booleanOptions\":{\"mode\":\"mapping\",\"trueValues\":[\"in stock\",\"available\",\"yes\"],\"onUnknown\":\"false\"}},"
    ++ "\"schemaPrice\":{\"selector\":\"script[type='application/ld+json']\",\"type\":\"json\",\"jsonOptions\":{\"path\":\"offers.price\"}}"
    ++ "}}"
  switch runFixture(~html, ~schema) {
  | Ok(value) => {
      let out = NodeJsBinding.jsonStringify(value)
      isTruthy(TestHelpers.stringContains(out, "1234.56"))
      isTruthy(TestHelpers.stringContains(out, "fast"))
      isTruthy(TestHelpers.stringContains(out, "cheap"))
    }
  | Error(_) => failWith("other fixture should parse")
  }
})

test("fixtures: row mode with default fallback on missing required", () => {
  let html =
    "<div class='row'><span class='name'>A</span><span class='price'>10</span></div>"
    ++ "<div class='row'><span class='name'>B</span></div>"
  let schema =
    "{\"fields\":{"
    ++ "\"name\":{\"selector\":\".name\",\"type\":\"text\"},"
    ++ "\"price\":{\"selector\":\".price\",\"type\":\"number\",\"required\":true,\"default\":0}"
    ++ "},\"config\":{\"rowSelector\":\".row\",\"ignoreErrors\":true}}"

  switch runFixture(~html, ~schema) {
  | Ok(value) => isTextEqualTo("[{\"name\":\"A\",\"price\":10},{\"name\":\"B\",\"price\":0}]", NodeJsBinding.jsonStringify(value))
  | Error(_) => failWith("Expected row mode fallback output")
  }
})

test("fixtures: zip mode aggregate + scalar behavior", () => {
  let html =
    "<h3>A</h3><h3>B</h3><span class='tag'>x</span><span class='tag'>y</span><span class='tag'>y</span>"
  let schema =
    "{\"fields\":{"
    ++ "\"title\":{\"selector\":\"h3\",\"type\":\"text\"},"
    ++ "\"tagCount\":{\"selector\":\".tag\",\"type\":\"count\"},"
    ++ "\"tags\":{\"selector\":\".tag\",\"type\":\"list\",\"listOptions\":{\"itemType\":\"text\",\"unique\":true}}"
    ++ "}}"

  switch runFixture(~html, ~schema) {
  | Ok(value) =>
    isTextEqualTo(
      "[{\"title\":\"A\",\"tagCount\":3,\"tags\":[\"x\",\"y\"]},{\"title\":\"B\",\"tagCount\":3,\"tags\":[\"x\",\"y\"]}]",
      NodeJsBinding.jsonStringify(value),
    )
  | Error(_) => failWith("Expected zip aggregate behavior")
  }
})
