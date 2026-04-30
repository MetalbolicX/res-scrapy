/**
  * Collects and reports statistics for multi-URL fetch operations.
  *
  * Tracks:
  * - URLs attempted/succeeded/failed
  * - Rows extracted
  * - Duration
  * - Failed URLs with error messages
  *
  * Report is printed to stderr.
  */

type failedUrl = {
  url: string,
  reason: string,
}

type stats = {
  attempted: int,
  succeeded: int,
  failed: int,
  rowsExtracted: int,
  durationMs: float,
  failedUrls: array<failedUrl>,
}

/**
  * Creates an empty stats record.
  */
let empty: unit => stats

/**
  * Records a successful fetch + extraction.
  */
let recordSuccess: (stats, ~rowCount: int) => stats

/**
  * Records a failed fetch.
  */
let recordFailure: (stats, ~url: string, ~reason: string) => stats

/**
  * Sets the duration.
  */
let setDuration: (stats, float) => stats

/**
  * Prints the report to stderr.
  * Only shows "Failed URLs" section if there were failures.
  */
let printReport: (stats, ~err: string => unit) => unit
