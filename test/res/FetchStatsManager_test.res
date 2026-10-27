open Test
open Assertions

type expectedTotals = {
  attempted: int,
  succeeded: int,
  failed: int,
  rowsExtracted: int,
  shouldExitWithError: bool,
}

let assertTotals = (mgr, expected) => {
  isIntEqualTo(expected.attempted, FetchStatsManager.attempted(mgr), ~message="attempted")
  isIntEqualTo(expected.succeeded, FetchStatsManager.succeeded(mgr), ~message="succeeded")
  isIntEqualTo(expected.failed, FetchStatsManager.failed(mgr), ~message="failed")
  isIntEqualTo(
    expected.rowsExtracted,
    FetchStatsManager.rowsExtracted(mgr),
    ~message="rowsExtracted",
  )
  isTruthy(
    FetchStatsManager.shouldExitWithError(mgr) == expected.shouldExitWithError,
    ~message="shouldExitWithError",
  )
}

test("FetchStatsManager starts empty and does not request an error exit", () => {
  let mgr = FetchStatsManager.create()
  assertTotals(
    mgr,
    {attempted: 0, succeeded: 0, failed: 0, rowsExtracted: 0, shouldExitWithError: false},
  )
})

test("FetchStatsManager requests an error exit when every URL failed", () => {
  let mgr = FetchStatsManager.create()
  FetchStatsManager.recordFailure(mgr, ~url="a", ~reason="Timeout")
  FetchStatsManager.recordFailure(mgr, ~url="b", ~reason="Not Found")
  assertTotals(
    mgr,
    {attempted: 2, succeeded: 0, failed: 2, rowsExtracted: 0, shouldExitWithError: true},
  )
})

test("FetchStatsManager does not request an error exit after a partial success", () => {
  let mgr = FetchStatsManager.create()
  FetchStatsManager.recordSuccess(mgr, ~rowCount=2)
  FetchStatsManager.recordFailure(mgr, ~url="a", ~reason="Timeout")
  assertTotals(
    mgr,
    {attempted: 2, succeeded: 1, failed: 1, rowsExtracted: 2, shouldExitWithError: false},
  )
})

test("FetchStatsManager accumulates rows and counts zero-row successes", () => {
  let mgr = FetchStatsManager.create()
  FetchStatsManager.recordSuccess(mgr, ~rowCount=2)
  FetchStatsManager.recordSuccess(mgr, ~rowCount=3)
  FetchStatsManager.recordSuccess(mgr, ~rowCount=0)
  assertTotals(
    mgr,
    {attempted: 3, succeeded: 3, failed: 0, rowsExtracted: 5, shouldExitWithError: false},
  )
})

let captureReport = mgr => {
  let lines = []
  FetchStatsManager.printReport(mgr, ~err=line => lines->Array.push(line))
  lines
}

let asJson = lines => lines->Array.map(JSON.Encode.string)->JSON.Encode.array

test("FetchStatsManager prints the exact report with failed URLs in order", () => {
  let mgr = FetchStatsManager.create()
  FetchStatsManager.recordSuccess(mgr, ~rowCount=2)
  FetchStatsManager.recordSuccess(mgr, ~rowCount=3)
  FetchStatsManager.recordFailure(mgr, ~url="http://fail1.com", ~reason="Timeout")
  FetchStatsManager.recordFailure(mgr, ~url="http://fail2.com", ~reason="Not Found")
  FetchStatsManager.setDuration(mgr, 2500.0)
  isJsonEqualTo(
    asJson([
      "---",
      "res-scrapy report",
      "  URLs attempted:  4",
      "  URLs succeeded:  2",
      "  URLs failed:     2",
      "  Rows extracted:  5",
      "  Duration:        2.5s",
      "",
      "  Failed URLs:",
      "    http://fail1.com  → Timeout",
      "    http://fail2.com  → Not Found",
      "",
    ]),
    asJson(captureReport(mgr)),
  )
})

test("FetchStatsManager prints the exact report without a failed URL section", () => {
  let mgr = FetchStatsManager.create()
  FetchStatsManager.recordSuccess(mgr, ~rowCount=2)
  FetchStatsManager.setDuration(mgr, 2500.0)
  isJsonEqualTo(
    asJson([
      "---",
      "res-scrapy report",
      "  URLs attempted:  1",
      "  URLs succeeded:  1",
      "  URLs failed:     0",
      "  Rows extracted:  2",
      "  Duration:        2.5s",
      "",
    ]),
    asJson(captureReport(mgr)),
  )
})
