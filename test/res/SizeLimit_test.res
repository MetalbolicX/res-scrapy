open Test
open Assertions

let cases = [
  (4, "4 bytes"),
  (1048575, "1048575 bytes"),
  (1048576, "1 MB"),
  (1572864, "1572864 bytes"),
  (52428800, "50 MB"),
]

cases->Array.forEachWithIndex((item, index) => {
  let (bytes, expected) = item
  test(`SizeLimit.describe case ${Int.toString(index)}`, () => {
    isTextEqualTo(expected, SizeLimit.describe(bytes))
  })
})

test("SizeLimit.describe never renders a positive cap under 1 MiB as 0 MB", () => {
  [1, 512, 1023]->Array.forEach(bytes =>
    isTruthy(!TestHelpers.stringContains(SizeLimit.describe(bytes), "MB"))
  )
})

test("SizeLimit.maxInputBytes is the shared 50 MiB cap", () => {
  isIntEqualTo(52428800, SizeLimit.maxInputBytes)
  isTextEqualTo("50 MB", SizeLimit.describe(SizeLimit.maxInputBytes))
})
