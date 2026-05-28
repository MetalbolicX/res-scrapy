open Test
open Assertions

test("empty initializes with zeroed values", () => {
  let stats = Reporter.empty()
  isIntEqualTo(0, stats.attempted)
  isIntEqualTo(0, stats.succeeded)
  isIntEqualTo(0, stats.failed)
  isIntEqualTo(0, stats.rowsExtracted)
  isFloatEqualTo(0.0, stats.durationMs)
  isTruthy(stats.failedUrls->List.length == 0)
})

test("recordSuccess increments correctly", () => {
  let stats = Reporter.empty()
  let updated = Reporter.recordSuccess(stats, ~rowCount=5)

  isIntEqualTo(1, updated.attempted)
  isIntEqualTo(1, updated.succeeded)
  isIntEqualTo(0, updated.failed)
  isIntEqualTo(5, updated.rowsExtracted)
})

test("recordFailure increments correctly and prepends URL", () => {
  let stats = Reporter.empty()
  let updated = Reporter.recordFailure(stats, ~url="http://fail.com", ~reason="Timeout")

  isIntEqualTo(1, updated.attempted)
  isIntEqualTo(0, updated.succeeded)
  isIntEqualTo(1, updated.failed)

  let firstUrl = updated.failedUrls->List.head->Option.map(h => h.url)->Option.getOr("")
  isTextEqualTo("http://fail.com", firstUrl)
})

test("setDuration sets duration correctly", () => {
  let stats = Reporter.empty()
  let updated = Reporter.setDuration(stats, 1500.0)
  isFloatEqualTo(1500.0, updated.durationMs)
})

test("printReport calls err with correct formatting", () => {
  let stats = Reporter.empty()
  let updated1 = Reporter.recordSuccess(stats, ~rowCount=10)
  let updated2 = Reporter.recordFailure(updated1, ~url="http://fail1.com", ~reason="Not Found")
  let finalStats = Reporter.setDuration(updated2, 2500.0)

  let output = ref([])
  let mockErr = msg => {
    output := Array.concat(output.contents, [msg])
  }

  Reporter.printReport(finalStats, ~err=mockErr)

  let lines = output.contents
  isTruthy(lines->Array.includes("  URLs attempted:  2"))
  isTruthy(lines->Array.includes("  URLs succeeded:  1"))
  isTruthy(lines->Array.includes("  URLs failed:     1"))
  isTruthy(lines->Array.includes("  Rows extracted:  10"))
  isTruthy(lines->Array.includes("  Duration:        2.5s"))
  isTruthy(lines->Array.includes("  Failed URLs:"))
  isTruthy(lines->Array.includes("    http://fail1.com  → Not Found"))
})
