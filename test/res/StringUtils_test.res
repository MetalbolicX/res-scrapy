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

test("StringUtils.extractPattern rejects catastrophic but syntactically valid patterns", () => {
  isOptionEqualTo(None, StringUtils.extractPattern("aaaaaaaaaaaaaaaa", "(a+)+b"), ~eq=(a, b) =>
    a == b
  )
  isOptionEqualTo(None, StringUtils.extractPattern("aaaaaaaaaaaaaaaa", "(a|b)+"), ~eq=(a, b) =>
    a == b
  )
})

test("StringUtils.stripNonNumeric keeps signs and decimals", () => {
  isTextEqualTo("1234.56", StringUtils.stripNonNumeric("$1,234.56"))
  isTextEqualTo("-99.5", StringUtils.stripNonNumeric("USD -99.5"))
})

/* -------------------------------------------------------------------------- */
/* Regex parity tests — lock in behavior that must match prior child-process */
/* output after the refactor to in-process %re regex literals. */
/* -------------------------------------------------------------------------- */

test("StringUtils.extractPattern returns first match for simple literal", () => {
  isOptionEqualTo(Some("world"), StringUtils.extractPattern("hello world", "world"), ~eq=(a, b) =>
    a == b
  )
})

test("StringUtils.extractPattern supports character classes", () => {
  isOptionEqualTo(Some("ABC123"), StringUtils.extractPattern("id=ABC123 end", "[A-Z0-9]+"), ~eq=(
    a,
    b,
  ) => a == b)
})

test("StringUtils.extractPattern returns None for zero-width match", () => {
  /* "x*" matches zero-width anywhere in "abc", producing an empty match string.
     The implementation collapses empty output to None — same behavior we must
     preserve after refactoring to in-process regex. */
  isOptionEqualTo(None, StringUtils.extractPattern("abc", "x*"), ~eq=(a, b) => a == b)
})

test("StringUtils.extractPattern honors anchors", () => {
  isOptionEqualTo(Some("foo"), StringUtils.extractPattern("foobar", "^foo"), ~eq=(a, b) => a == b)
  isOptionEqualTo(None, StringUtils.extractPattern("barfoo", "^foo"), ~eq=(a, b) => a == b)
})

test("StringUtils.extractPattern respects case sensitivity by default", () => {
  isOptionEqualTo(None, StringUtils.extractPattern("HELLO", "hello"), ~eq=(a, b) => a == b)
  isOptionEqualTo(Some("HELLO"), StringUtils.extractPattern("HELLO", "HELLO"), ~eq=(a, b) => a == b)
})

test("StringUtils.extractPattern rejects patterns with lookaheads", () => {
  isOptionEqualTo(None, StringUtils.extractPattern("abc123", "(?=[0-9]+)abc"), ~eq=(a, b) => a == b)
})

test("StringUtils.extractPattern rejects patterns with backreferences", () => {
  isOptionEqualTo(None, StringUtils.extractPattern("aa", "(a)\\1"), ~eq=(a, b) => a == b)
})

test("StringUtils.extractPattern rejects overly large quantifiers", () => {
  isOptionEqualTo(None, StringUtils.extractPattern("aaaa", "a{10000}"), ~eq=(a, b) => a == b)
})

test("StringUtils.matchesPattern returns true for first match", () => {
  isTruthy(StringUtils.matchesPattern("price=42", "[0-9]+"))
})

test("StringUtils.matchesPattern returns false when no match", () => {
  isTruthy(StringUtils.matchesPattern("hello", "[0-9]+") == false)
})

test("StringUtils.matchesPattern returns false for catastrophic pattern", () => {
  isTruthy(StringUtils.matchesPattern("aaaaaaaaaaaaaaaa", "(a+)+b") == false)
})

test("StringUtils.matchesPattern returns false for invalid regex", () => {
  isTruthy(StringUtils.matchesPattern("abc", "([") == false)
})

test("StringUtils.matchesPattern returns true for empty input with quantifier-only pattern", () => {
  isTruthy(StringUtils.matchesPattern("", "a*"))
})
