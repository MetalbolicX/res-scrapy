open Test
open Assertions
open FieldTypes

let absFloat = n => n < 0.0 ? -.n : n
let eqFloat = (a, b) => absFloat(a -. b) <= 0.000001

[
  ("1e5", Some(100000.0)),
  ("1.5E-3", Some(0.0015)),
  ("-2e3", Some(-2000.0)),
  ("2e+3", Some(2000.0)),
  ("5 items each", Some(5.0)),
  ("45%", Some(45.0)),
  ("3,14", Some(314.0)),
  ("", None),
  ("-", None),
  ("1e", Some(1.0)),
  ("e5", Some(5.0)),
  ("$1,234.50", Some(1234.5)),
  ("1.2.3", Some(1.2)),
  ("-$5", Some(-5.0)),
  ("1 e5", Some(15.0)),
  ("1e +3", Some(13.0)),
  ("1e+ 3", Some(13.0)),
  ("1+2", Some(12.0)),
]->Array.forEach(((input, expected)) => {
  test(`NumberUtils default cleanup: ${input}`, () => {
    isOptionEqualTo(expected, NumberUtils.parseWithOptions(input, None), ~eq=eqFloat)
  })
})

test("NumberUtils scientific notation respects options", () => {
  isOptionEqualTo(
    Some(3.14),
    NumberUtils.parseWithOptions("3,14", Some({decimalSeparator: ","})),
    ~eq=eqFloat,
  )
  isOptionEqualTo(
    Some(2000.0),
    NumberUtils.parseWithOptions("2e+3", Some({stripNonNumeric: false})),
    ~eq=eqFloat,
  )
  isOptionEqualTo(
    None,
    NumberUtils.parseWithOptions("-2e3", Some({allowNegative: false})),
    ~eq=eqFloat,
  )
})

test("NumberUtils.parseWithOptions parses plain values", () => {
  isOptionEqualTo(Some(42.0), NumberUtils.parseWithOptions("42", None), ~eq=eqFloat)
  isOptionEqualTo(Some(3.14), NumberUtils.parseWithOptions("3.14", None), ~eq=eqFloat)
})

test("NumberUtils.parseWithOptions strips symbols by default", () => {
  isOptionEqualTo(Some(19.99), NumberUtils.parseWithOptions("$19.99", None), ~eq=eqFloat)
})

test("NumberUtils.parseWithOptions supports separators", () => {
  let opts1: option<numberOptions> = Some({thousandsSeparator: ","})
  let opts2: option<numberOptions> = Some({stripNonNumeric: false, decimalSeparator: ","})
  isOptionEqualTo(Some(1234.56), NumberUtils.parseWithOptions("1,234.56", opts1), ~eq=eqFloat)
  isOptionEqualTo(Some(3.14), NumberUtils.parseWithOptions("3,14", opts2), ~eq=eqFloat)
})

test("NumberUtils.parseWithOptions normalizes locale separators before default stripping", () => {
  let opts = Some({thousandsSeparator: ".", decimalSeparator: ","})
  isOptionEqualTo(Some(1234.56), NumberUtils.parseWithOptions("1.234,56", opts), ~eq=eqFloat)
})

test("NumberUtils.parseWithOptions strips currency before parsing locale separators", () => {
  let opts = Some({thousandsSeparator: ".", decimalSeparator: ","})
  isOptionEqualTo(Some(1234.56), NumberUtils.parseWithOptions("€ 1.234,56", opts), ~eq=eqFloat)
})

test("NumberUtils.parseWithOptions supports decimal separator with default stripping", () => {
  let opts = Some({decimalSeparator: ","})
  isOptionEqualTo(Some(1234.56), NumberUtils.parseWithOptions("1234,56", opts), ~eq=eqFloat)
})

test("NumberUtils.parseWithOptions preserves standard US number parsing", () => {
  isOptionEqualTo(Some(1234.56), NumberUtils.parseWithOptions("$1,234.56", None), ~eq=eqFloat)
})

test("NumberUtils.parseWithOptions applies precision", () => {
  let opts: option<numberOptions> = Some({precision: 2})
  isOptionEqualTo(Some(3.14), NumberUtils.parseWithOptions("3.14159", opts), ~eq=eqFloat)
})

test("NumberUtils.parseWithOptions supports pattern extraction", () => {
  let opts: option<numberOptions> = Some({pattern: "Price:\\s*\\$([0-9.]+)"})
  isOptionEqualTo(Some(42.0), NumberUtils.parseWithOptions("Price: $42.00", opts), ~eq=eqFloat)
})

test("NumberUtils.parseWithOptions rejects catastrophic regex patterns", () => {
  let opts1: option<numberOptions> = Some({pattern: "(a+)+b"})
  let opts2: option<numberOptions> = Some({pattern: "(a|b)+"})
  isOptionEqualTo(None, NumberUtils.parseWithOptions("aaaaaaaaaaaaaaaa", opts1), ~eq=eqFloat)
  isOptionEqualTo(None, NumberUtils.parseWithOptions("aaaaaaaaaaaaaaaa", opts2), ~eq=eqFloat)
})

test("NumberUtils.parseWithOptions blocks negative when configured", () => {
  let opts: option<numberOptions> = Some({allowNegative: false})
  isOptionEqualTo(None, NumberUtils.parseWithOptions("-12.5", opts), ~eq=eqFloat)
})

test("NumberUtils.parseWithOptions returns None for empty and NaN", () => {
  isOptionEqualTo(None, NumberUtils.parseWithOptions("", None), ~eq=eqFloat)
  isOptionEqualTo(
    None,
    NumberUtils.parseWithOptions("abc", Some({stripNonNumeric: false})),
    ~eq=eqFloat,
  )
})
