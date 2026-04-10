open Test
open Assertions

test("StringUtils.trimStr trims boundaries", () => {
  isTextEqualTo("hello", StringUtils.trimStr("  hello  "))
  isTextEqualTo("", StringUtils.trimStr("   "))
})

test("StringUtils.normalizeWhitespace collapses runs", () => {
  isTextEqualTo("a b c", StringUtils.normalizeWhitespace("  a\n\tb   c  "))
})

test("StringUtils.case conversion", () => {
  isTextEqualTo("hello", StringUtils.toLower("HeLLo"))
  isTextEqualTo("HELLO", StringUtils.toUpper("HeLLo"))
})

test("StringUtils.extractPattern returns first capture", () => {
  let out = StringUtils.extractPattern("Price: $42.50", "([0-9]+\\.[0-9]+)")
  isOptionEqualTo(Some("42.50"), out, ~eq=(a, b) => a == b)
})

test("StringUtils.extractPattern handles no match and invalid regex", () => {
  isOptionEqualTo(None, StringUtils.extractPattern("abc", "x([0-9]+)"), ~eq=(a, b) => a == b)
  isOptionEqualTo(None, StringUtils.extractPattern("abc", "(["), ~eq=(a, b) => a == b)
})

test("StringUtils.stripNonNumeric keeps signs and decimals", () => {
  isTextEqualTo("1234.56", StringUtils.stripNonNumeric("$1,234.56"))
  isTextEqualTo("-99.5", StringUtils.stripNonNumeric("USD -99.5"))
})
