open Test
open Assertions
open FieldTypes

let absFloat = n => n < 0.0 ? -.n : n
let eqFloat = (a, b) => absFloat(a -. b) <= 0.000001

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

test("NumberUtils.parseWithOptions applies precision", () => {
  let opts: option<numberOptions> = Some({precision: 2})
  isOptionEqualTo(Some(3.14), NumberUtils.parseWithOptions("3.14159", opts), ~eq=eqFloat)
})

test("NumberUtils.parseWithOptions supports pattern extraction", () => {
  let opts: option<numberOptions> = Some({pattern: "Price:\\s*\\$([0-9.]+)"})
  isOptionEqualTo(
    Some(42.0),
    NumberUtils.parseWithOptions("Price: $42.00", opts),
    ~eq=eqFloat,
  )
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
