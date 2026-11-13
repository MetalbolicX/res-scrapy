open Test
open Assertions
open DateUtils

[
  ("2024-01-02 15:04", "2024-01-02T15:04:00Z"),
  ("2024-01-02T15:04", "2024-01-02T15:04:00Z"),
  ("2024-01-02T15:04:05", "2024-01-02T15:04:05Z"),
  ("2024-01-02T15:04:05.123", "2024-01-02T15:04:05Z"),
  ("2024-01-02", "2024-01-02T00:00:00Z"),
  ("2024-01-02T15:04:00Z", "2024-01-02T15:04:00Z"),
  ("2024-01-02T15:04:00+02:00", "2024-01-02T13:04:00Z"),
  ("2024-01-02T15:04:00-06:00", "2024-01-02T21:04:00Z"),
]->Array.forEach(((input, expected)) => {
  test(`DateUtils ISO UTC: ${input}`, () => {
    switch parseDate(input, ["ISO"]) {
    | Some(date) => isTextEqualTo(expected, formatDate(date, FieldTypes.Iso8601, Some("UTC")))
    | None => failWith("Expected valid ISO date")
    }
  })
})

test("DateUtils offset-less fallback and custom format remain UTC", () => {
  [[], ["yyyy-MM-dd HH:mm"]]->Array.forEach(formats => {
    switch parseDate("2024-01-02 15:04", formats) {
    | Some(date) =>
      isTextEqualTo("2024-01-02T15:04:00Z", formatDate(date, FieldTypes.Iso8601, Some("UTC")))
    | None => failWith("Expected valid date")
    }
  })
})

test("DateUtils rejects empty and invalid ISO input", () => {
  ["", "nope"]->Array.forEach(input => {
    switch parseDate(input, ["ISO"]) {
    | None => passWith("Invalid input rejected")
    | Some(_) => failWith("Expected parse failure")
    }
  })
})

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

let isoUtc = date => formatDate(date, FieldTypes.Iso8601, Some("UTC"))

[
  ("02/30/2024", "MM/dd/yyyy"),
  ("13/01/2024", "MM/dd/yyyy"),
  ("02/29/2023", "MM/dd/yyyy"),
  ("2024-01-01 24:00", "yyyy-MM-dd HH:mm"),
]->Array.forEach(((input, format)) => {
  test(`DateUtils rejects invalid calendar parts: ${input} as ${format}`, () => {
    switch parseDate(input, [format]) {
    | None => passWith("Invalid calendar date rejected")
    | Some(date) => failWith(`Expected None, got ${isoUtc(date)}`)
    }
  })
})

test("DateUtils accepts leap day 02/29/2024", () => {
  switch parseDate("02/29/2024", ["MM/dd/yyyy"]) {
  | Some(date) => isTextEqualTo("2024-02-29T00:00:00Z", isoUtc(date))
  | None => failWith("Expected valid leap day")
  }
})

["Mar 14 2023", "2024"]->Array.forEach(input => {
  test(`DateUtils ISO is strict ISO 8601: ${input}`, () => {
    switch parseDate(input, ["ISO"]) {
    | None => passWith("Non-ISO input rejected")
    | Some(date) => failWith(`Expected None, got ${isoUtc(date)}`)
    }
  })
})

test("DateUtils keeps four-digit years below 100", () => {
  switch parseDate("0099-01-01", ["yyyy-MM-dd"]) {
  | Some(date) => isTextEqualTo("0099-01-01T00:00:00Z", isoUtc(date))
  | None => failWith("Expected valid year 0099")
  }
})

test("DateUtils parses epoch seconds", () => {
  switch parseDate("1717200000", ["epoch"]) {
  | Some(date) => isTextEqualTo("2024-06-01T00:00:00Z", isoUtc(date))
  | None => failWith("Expected valid epoch seconds")
  }
})

test("DateUtils rejects out-of-range epoch millis", () => {
  switch parseDate("9000000000000000", ["epochMillis"]) {
  | None => passWith("Out-of-range epoch rejected")
  | Some(date) => failWith(`Expected None, got ${isoUtc(date)}`)
  }
})
