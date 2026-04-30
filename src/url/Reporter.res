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

let empty = () => {
  attempted: 0,
  succeeded: 0,
  failed: 0,
  rowsExtracted: 0,
  durationMs: 0.0,
  failedUrls: [],
}

let recordSuccess = (stats, ~rowCount) => {
  {
    ...stats,
    attempted: stats.attempted + 1,
    succeeded: stats.succeeded + 1,
    rowsExtracted: stats.rowsExtracted + rowCount,
  }
}

let recordFailure = (stats, ~url, ~reason) => {
  {
    ...stats,
    attempted: stats.attempted + 1,
    failed: stats.failed + 1,
    failedUrls: Array.concat(stats.failedUrls, [{url, reason}]),
  }
}

let setDuration = (stats, durationMs) => {
  {...stats, durationMs}
}

let printReport = (stats, ~err) => {
  err("---")
  err("res-scrapy report")
  err(`  URLs attempted:  ${Int.toString(stats.attempted)}`)
  err(`  URLs succeeded:  ${Int.toString(stats.succeeded)}`)
  err(`  URLs failed:     ${Int.toString(stats.failed)}`)
  err(`  Rows extracted:  ${Int.toString(stats.rowsExtracted)}`)
  
  let durationSec = stats.durationMs /. 1000.0
  err(`  Duration:        ${Float.toString(durationSec)}s`)
  
  if stats.failed > 0 {
    err("")
    err("  Failed URLs:")
    stats.failedUrls->Array.forEach(failed => {
      err(`    ${failed.url}  → ${failed.reason}`)
    })
  }
  err("")
}
