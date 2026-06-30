/**
  * FetchStatsManager — fetch-cycle statistics aggregation for URL mode.
  *
  * Sits on top of the existing `Reporter` module which owns the underlying
  * record types (stats, failedUrl). The manager wraps them in a mutable
  * session-style API so that UrlRunner's run loop no longer threads
  * `ref(Reporter.stats)` references through the body — it just calls
  * `FetchStatsManager.recordFailure(mgr, ~url, ~reason)` etc.
  *
  * All values are recorded through `Reporter` so existing
  * `Reporter_test.res` / `ReporterPipeline_test.res` cases continue to
  * pass unchanged. This module adds a thin convenience surface for the
  * orchestration layer; it does NOT duplicate the storage shape.
  */

type t = {
  mutable stats: Reporter.stats,
}

let create = () => {
  stats: Reporter.empty(),
}

let current = (mgr: t): Reporter.stats => mgr.stats

let recordSuccess = (mgr: t, ~rowCount: int) => {
  mgr.stats = Reporter.recordSuccess(mgr.stats, ~rowCount)
}

let recordFailure = (mgr: t, ~url: string, ~reason: string) => {
  mgr.stats = Reporter.recordFailure(mgr.stats, ~url, ~reason)
}

let setDuration = (mgr: t, durationMs: float) => {
  mgr.stats = Reporter.setDuration(mgr.stats, durationMs)
}

let printReport = (mgr: t, ~err: string => unit) => {
  Reporter.printReport(mgr.stats, ~err)
}

/* Pure decision helpers — extracted here so UrlRunner's exit-code branch
   reads as plain English rather than a numeric comparison. */

let shouldExitWithError = (mgr: t): bool =>
  mgr.stats.succeeded == 0 && mgr.stats.failed > 0

let attempted = (mgr: t): int => mgr.stats.attempted
let succeeded = (mgr: t): int => mgr.stats.succeeded
let failed = (mgr: t): int => mgr.stats.failed
let rowsExtracted = (mgr: t): int => mgr.stats.rowsExtracted
