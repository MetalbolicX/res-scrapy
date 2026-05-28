open Test
open Assertions
open DateUtils

let _ = test("DateUtils - parseDate tries formats in order", () => {
  // 2024-01-01T12:00:00Z should parse correctly with ISO
  let parsed = parseDate("2024-01-01T12:00:00Z", ["ISO"])
  switch parsed {
  | Some(_date) => passWith("ISO format parsed")
  | None => failWith("Expected valid date")
  }

  // Fallback to ISO if empty formats array
  let parsed2 = parseDate("2024-01-01T12:00:00Z", [])
  switch parsed2 {
  | Some(_) => passWith("Empty format array parsed with ISO fallback")
  | None => failWith("Expected valid date with empty format array")
  }
})

let _ = test("DateUtils - formatDate", () => {
  let parsed = parseDate("2024-01-01T12:00:00Z", ["ISO"])
  switch parsed {
  | Some(date) => {
      let formatted = formatDate(date, FieldTypes.Iso8601, Some("UTC"))
      isTextEqualTo("2024-01-01T12:00:00Z", formatted)

      let epochFormatted = formatDate(date, FieldTypes.Epoch, None)
      isTextEqualTo("1704110400", epochFormatted)

      let epochMillisFormatted = formatDate(date, FieldTypes.EpochMillis, None)
      isTextEqualTo("1704110400000", epochMillisFormatted)

      let customFormatted = formatDate(date, FieldTypes.Custom("yyyy-MM-dd"), Some("UTC"))
      isTextEqualTo("2024-01-01", customFormatted)
    }
  | None => failWith("Setup failed")
  }
})
