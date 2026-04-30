open Test
open Assertions

test("parse returns single URL when no template braces", () => {
  switch TemplateParser.parse("https://example.com/page") {
  | Ok(urls) => isIntEqualTo(1, Array.length(urls))
  | Error(_) => failWith("Expected Ok")
  }
  
  switch TemplateParser.parse("https://example.com/page") {
  | Ok(urls) => isTextEqualTo("https://example.com/page", Array.get(urls, 0)->Option.getOr("wrong"))
  | Error(_) => failWith("Expected Ok")
  }
})

test("parse expands simple range {1..3}", () => {
  switch TemplateParser.parse("https://api.com/items/{1..3}") {
  | Ok(urls) => {
      isIntEqualTo(3, Array.length(urls))
      isTextEqualTo("https://api.com/items/1", Array.get(urls, 0)->Option.getOr("wrong"))
      isTextEqualTo("https://api.com/items/2", Array.get(urls, 1)->Option.getOr("wrong"))
      isTextEqualTo("https://api.com/items/3", Array.get(urls, 2)->Option.getOr("wrong"))
    }
  | Error(e) => failWith(`Expected Ok, got: ${TemplateParser.parseErrorToMessage(e)}`)
  }
})

test("parse expands range with step {0..10..5}", () => {
  switch TemplateParser.parse("https://api.com/offset={0..10..5}") {
  | Ok(urls) => {
      isIntEqualTo(3, Array.length(urls))
      isTextEqualTo("https://api.com/offset=0", Array.get(urls, 0)->Option.getOr("wrong"))
      isTextEqualTo("https://api.com/offset=5", Array.get(urls, 1)->Option.getOr("wrong"))
      isTextEqualTo("https://api.com/offset=10", Array.get(urls, 2)->Option.getOr("wrong"))
    }
  | Error(e) => failWith(`Expected Ok, got: ${TemplateParser.parseErrorToMessage(e)}`)
  }
})

test("parse expands zero-padded range {001..003}", () => {
  switch TemplateParser.parse("https://api.com/item={001..003}") {
  | Ok(urls) => {
      isIntEqualTo(3, Array.length(urls))
      isTextEqualTo("https://api.com/item=001", Array.get(urls, 0)->Option.getOr("wrong"))
      isTextEqualTo("https://api.com/item=002", Array.get(urls, 1)->Option.getOr("wrong"))
      isTextEqualTo("https://api.com/item=003", Array.get(urls, 2)->Option.getOr("wrong"))
    }
  | Error(e) => failWith(`Expected Ok, got: ${TemplateParser.parseErrorToMessage(e)}`)
  }
})

test("parse returns InvalidSyntax for unmatched opening brace", () => {
  switch TemplateParser.parse("https://api.com/{page") {
  | Error(InvalidSyntax(_)) => passWith("correct error")
  | Error(_) => failWith("Expected InvalidSyntax")
  | Ok(_) => failWith("Expected Error")
  }
})

test("parse returns InvalidSyntax for unmatched closing brace", () => {
  switch TemplateParser.parse("https://api.com/page}") {
  | Error(InvalidSyntax(_)) => passWith("correct error")
  | Error(_) => failWith("Expected InvalidSyntax")
  | Ok(_) => failWith("Expected Error")
  }
})

test("parse returns InvalidSyntax for multiple templates", () => {
  switch TemplateParser.parse("https://api.com/{a}/{b}") {
  | Error(InvalidSyntax(_)) => passWith("correct error")
  | Error(_) => failWith("Expected InvalidSyntax")
  | Ok(_) => failWith("Expected Error")
  }
})

test("parse returns InvalidRange when start > end", () => {
  switch TemplateParser.parse("https://api.com/{10..1}") {
  | Error(InvalidRange(_)) => passWith("correct error")
  | Error(_) => failWith("Expected InvalidRange")
  | Ok(_) => failWith("Expected Error")
  }
})

test("parse returns InvalidRange when step is 0", () => {
  switch TemplateParser.parse("https://api.com/{1..10..0}") {
  | Error(InvalidRange(_)) => passWith("correct error")
  | Error(_) => failWith("Expected InvalidRange")
  | Ok(_) => failWith("Expected Error")
  }
})

test("parse returns InvalidRange when step is negative", () => {
  switch TemplateParser.parse("https://api.com/{10..1..-2}") {
  | Error(InvalidRange(_)) => passWith("correct error")
  | Error(_) => failWith("Expected InvalidRange")
  | Ok(_) => failWith("Expected Error")
  }
})

test("parse handles range at end of URL", () => {
  switch TemplateParser.parse("https://api.com/page{1..2}") {
  | Ok(urls) => {
      isIntEqualTo(2, Array.length(urls))
      isTextEqualTo("https://api.com/page1", Array.get(urls, 0)->Option.getOr("wrong"))
      isTextEqualTo("https://api.com/page2", Array.get(urls, 1)->Option.getOr("wrong"))
    }
  | Error(e) => failWith(`Expected Ok, got: ${TemplateParser.parseErrorToMessage(e)}`)
  }
})

test("parse handles range in middle of URL", () => {
  switch TemplateParser.parse("https://api.com/{1..2}/items") {
  | Ok(urls) => {
      isIntEqualTo(2, Array.length(urls))
      isTextEqualTo("https://api.com/1/items", Array.get(urls, 0)->Option.getOr("wrong"))
      isTextEqualTo("https://api.com/2/items", Array.get(urls, 1)->Option.getOr("wrong"))
    }
  | Error(e) => failWith(`Expected Ok, got: ${TemplateParser.parseErrorToMessage(e)}`)
  }
})

test("parse returns InvalidSyntax for invalid range syntax", () => {
  switch TemplateParser.parse("https://api.com/{abc}") {
  | Error(InvalidSyntax(_)) => passWith("correct error")
  | Error(_) => failWith("Expected InvalidSyntax")
  | Ok(_) => failWith("Expected Error")
  }
})

test("parse handles single item range {5..5}", () => {
  switch TemplateParser.parse("https://api.com/item={5..5}") {
  | Ok(urls) => {
      isIntEqualTo(1, Array.length(urls))
      isTextEqualTo("https://api.com/item=5", Array.get(urls, 0)->Option.getOr("wrong"))
    }
  | Error(e) => failWith(`Expected Ok, got: ${TemplateParser.parseErrorToMessage(e)}`)
  }
})
