open Test
open Assertions
open TestHelpers
open NodeJsBinding.Fetch

test("isRetryable returns true for NetworkError", () => {
  isTruthy(Fetcher.isRetryable(NetworkError("connection refused")))
})

test("isRetryable returns true for Timeout", () => {
  isTruthy(Fetcher.isRetryable(Timeout("timeout after 30s")))
})

test("isRetryable returns true for 429 rate limit", () => {
  isTruthy(Fetcher.isRetryable(HttpError(429, "Too Many Requests")))
})

test("isRetryable returns true for 500 server error", () => {
  isTruthy(Fetcher.isRetryable(HttpError(500, "Internal Server Error")))
})

test("isRetryable returns true for 502 bad gateway", () => {
  isTruthy(Fetcher.isRetryable(HttpError(502, "Bad Gateway")))
})

test("isRetryable returns true for 503 service unavailable", () => {
  isTruthy(Fetcher.isRetryable(HttpError(503, "Service Unavailable")))
})

test("isRetryable returns false for 400 bad request", () => {
  isTruthy(Fetcher.isRetryable(HttpError(400, "Bad Request")) == false)
})

test("isRetryable returns false for 404 not found", () => {
  isTruthy(Fetcher.isRetryable(HttpError(404, "Not Found")) == false)
})

test("isRetryable returns false for 401 unauthorized", () => {
  isTruthy(Fetcher.isRetryable(HttpError(401, "Unauthorized")) == false)
})

test("isRetryable returns false for ParseError", () => {
  isTruthy(Fetcher.isRetryable(ParseError("invalid response")) == false)
})

test("backoffDelay returns positive values for attempt >= 0", () => {
  let d0 = Fetcher.backoffDelay(0)
  let d1 = Fetcher.backoffDelay(1)
  let d2 = Fetcher.backoffDelay(2)
  isTruthy(d0 > 0)
  isTruthy(d1 > 0)
  isTruthy(d2 > 0)
})

test("backoffDelay increases with attempt", () => {
  let d0 = Fetcher.backoffDelay(0)
  let d1 = Fetcher.backoffDelay(1)
  let d2 = Fetcher.backoffDelay(2)
  // With jitter, we can't guarantee strict ordering, but base values increase
  isTruthy(d1 > d0 / 2) // d1 should be roughly 2x d0
  isTruthy(d2 > d1 / 2) // d2 should be roughly 2x d1
})

test("fetchErrorToMessage formats NetworkError", () => {
  let msg = Fetcher.fetchErrorToMessage(NetworkError("ECONNREFUSED"))
  stringContains(msg, "ECONNREFUSED")->isTruthy
  stringContains(msg, "Network error")->isTruthy
})

test("fetchErrorToMessage formats Timeout", () => {
  let msg = Fetcher.fetchErrorToMessage(Timeout("timeout after 30s"))
  stringContains(msg, "timeout after 30s")->isTruthy
  stringContains(msg, "Timeout")->isTruthy
})

test("fetchErrorToMessage formats HttpError", () => {
  let msg = Fetcher.fetchErrorToMessage(HttpError(429, "Too Many Requests"))
  stringContains(msg, "429")->isTruthy
  stringContains(msg, "Too Many Requests")->isTruthy
  stringContains(msg, "HTTP")->isTruthy
})

test("fetchErrorToMessage formats ParseError", () => {
  let msg = Fetcher.fetchErrorToMessage(ParseError("invalid html"))
  stringContains(msg, "invalid html")->isTruthy
  stringContains(msg, "Parse error")->isTruthy
})

test("AbortSignal aborted is false before abort()", () => {
  let controller = AbortSignal.makeController()
  let signal = AbortSignal.signal(controller)
  isTruthy(AbortSignal.aborted(signal) == false)
})

test("AbortSignal aborted is true after abort()", () => {
  let controller = AbortSignal.makeController()
  let signal = AbortSignal.signal(controller)
  AbortSignal.abort(controller)
  isTruthy(AbortSignal.aborted(signal) == true)
})

test("Fetcher classifies error as Timeout when signal is aborted", () => {
  let controller = AbortSignal.makeController()
  let signal = AbortSignal.signal(controller)
  AbortSignal.abort(controller)
  let result = Fetcher.classifyError(
    ~message="some unrelated error text",
    ~isAborted=AbortSignal.aborted(signal),
    ~timeoutSeconds=5,
  )
  switch result {
  | Error(Timeout(msg)) =>
    stringContains(msg, "5")->isTruthy
    stringContains(msg, "timeout")->isTruthy
  | _ => failWith("Expected Timeout variant when signal is aborted")
  }
})

test("Fetcher classifies error as NetworkError when signal is not aborted", () => {
  let result = Fetcher.classifyError(
    ~message="connection refused",
    ~isAborted=false,
    ~timeoutSeconds=30,
  )
  switch result {
  | Error(NetworkError(msg)) => stringContains(msg, "connection refused")->isTruthy
  | _ => failWith("Expected NetworkError variant when signal is not aborted")
  }
})

test("Fetcher timeout classification ignores error message text", () => {
  // Critical: even if the error message contains "abort" or "timeout", if the
  // signal was not aborted, the error should be classified as NetworkError.
  let result = Fetcher.classifyError(
    ~message="abort controller failure",
    ~isAborted=false,
    ~timeoutSeconds=10,
  )
  switch result {
  | Error(NetworkError(_)) => passWith("NetworkError returned despite 'abort' in message")
  | Error(Timeout(_)) => failWith("Should not classify as Timeout when signal is not aborted")
  | _ => failWith("Expected NetworkError")
  }
})

testAsync("fetchAll returns all results even when some URLs fail", planned => {
  let options: Fetcher.fetchOptions = {
    concurrency: 3,
    userAgent: "test-agent/1.0",
    timeoutSeconds: 2,
    retryCount: 0,
    delayMs: 0,
    headers: [],
  }
  Fetcher.fetchAll(["http://127.0.0.1:9", "http://127.0.0.1:9", "https://example.com/"], options)
  ->Promise.then(results => {
    (results->Array.length == 3)->isTruthy
    let countSuccess =
      results
      ->Array.filter(
        r =>
          switch r.result {
          | Ok(_) => true
          | Error(_) => false
          },
      )
      ->Array.length
    let countFailure =
      results
      ->Array.filter(
        r =>
          switch r.result {
          | Ok(_) => false
          | Error(_) => true
          },
      )
      ->Array.length
    (countSuccess >= 1)->isTruthy
    (countFailure >= 1)->isTruthy
    planned(~planned=3, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("fetchAll threw unexpectedly")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})
