open Test
open Assertions

test("three successful extractions reports 3 successes, 0 failures, 0 skips", () => {
  let stats = Reporter.empty()
  let afterA = Reporter.recordSuccess(stats, ~rowCount=1)
  let afterB = Reporter.recordSuccess(afterA, ~rowCount=1)
  let afterC = Reporter.recordSuccess(afterB, ~rowCount=1)

  isIntEqualTo(3, afterC.attempted)
  isIntEqualTo(3, afterC.succeeded)
  isIntEqualTo(0, afterC.failed)
  isIntEqualTo(3, afterC.rowsExtracted)
})

test("one failure two successes reports 2 successes, 1 failure, 0 skips", () => {
  let stats = Reporter.empty()
  let afterA = Reporter.recordSuccess(stats, ~rowCount=1)
  let afterB = Reporter.recordFailure(afterA, ~url="http://fail.com", ~reason="Timeout")
  let afterC = Reporter.recordSuccess(afterB, ~rowCount=1)

  isIntEqualTo(3, afterC.attempted)
  isIntEqualTo(2, afterC.succeeded)
  isIntEqualTo(1, afterC.failed)
})

test("multiple failures increments counter correctly", () => {
  let stats = Reporter.empty()
  let afterA = Reporter.recordFailure(stats, ~url="http://fail1.com", ~reason="Not Found")
  let afterB = Reporter.recordFailure(afterA, ~url="http://fail2.com", ~reason="Timeout")
  let afterC = Reporter.recordFailure(afterB, ~url="http://fail3.com", ~reason="Server Error")

  isIntEqualTo(3, afterC.attempted)
  isIntEqualTo(0, afterC.succeeded)
  isIntEqualTo(3, afterC.failed)
  isIntEqualTo(3, afterC.failedUrls->List.length)
})

test("setDuration sets duration correctly after multiple operations", () => {
  let stats = Reporter.empty()
  let afterOp = Reporter.recordSuccess(stats, ~rowCount=5)
  let final = Reporter.setDuration(afterOp, 1500.0)

  isFloatEqualTo(1500.0, final.durationMs)
  isIntEqualTo(1, final.attempted)
  isIntEqualTo(1, final.succeeded)
  isIntEqualTo(5, final.rowsExtracted)
})

test("failedUrls list prepends in order received", () => {
  let stats = Reporter.empty()
  let afterA = Reporter.recordFailure(stats, ~url="http://first.com", ~reason="First")
  let afterB = Reporter.recordFailure(afterA, ~url="http://second.com", ~reason="Second")
  let afterC = Reporter.recordFailure(afterB, ~url="http://third.com", ~reason="Third")

  let urls = afterC.failedUrls
  let firstUrl = urls->List.head->Option.map(h => h.url)->Option.getOr("")
  isTextEqualTo("http://third.com", firstUrl)
})

test("empty reporter returns zeroed values", () => {
  let stats = Reporter.empty()
  isIntEqualTo(0, stats.attempted)
  isIntEqualTo(0, stats.succeeded)
  isIntEqualTo(0, stats.failed)
  isIntEqualTo(0, stats.rowsExtracted)
  isFloatEqualTo(0.0, stats.durationMs)
  isTruthy(stats.failedUrls->List.length == 0)
})
