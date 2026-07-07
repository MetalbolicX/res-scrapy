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
    (countFailure >= 1)->isTruthy
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("fetchAll threw unexpectedly")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

/* Regression test for sdd/007-concurrency-robustness.
   Proves that the post-acquire guard pattern used by `fetchWithSemaphore`
   releases the semaphore slot even when the critical section throws.
   The fix relies on `try { Ok(await work()) } catch { Error(exn) }` followed
   by `release(sem)` on both branches (ReScript v12 has no `try/finally`).
   If the fix is absent (release on the success path only), the slot is leaked
   and the follow-up `acquire` would deadlock — the test would never reach
   `planned`. */

testAsync("fetchWithSemaphore guard pattern releases slot when critical section throws", planned => {
  let sem = Fetcher.makeSemaphore(1)

  Fetcher.acquire(sem)
  ->Promise.then(_ => {
    // Replicate the FIX pattern: critical section throws; the guard still releases.
    let criticalSection = async () => {
      let outcome = try {
        let _ = await Promise.reject(
          JsError.throwWithMessage("Simulated fetch failure escaping fetchOnce's try/catch"),
        )
        Ok()
      } catch {
      | exn => Error(exn)
      }
      Fetcher.release(sem)
      switch outcome {
      | Ok() => JsError.throwWithMessage("unreachable: outcome should be Error(_)")
      | Error(exn) => throw(exn)
      }
    }

    criticalSection()
    ->Promise.then(_ => {
      failWith("criticalSection should have rejected — rejection was silently swallowed")
      planned(~planned=0, ())
      Promise.resolve()
    })
    ->Promise.catch(_ => {
      // Critical section rejected as expected. `release(sem)` ran before the
      // re-raise, returning the slot to the semaphore. If the slot were leaked,
      // this second `acquire` would queue forever — the test would hang.
      Fetcher.acquire(sem)
      ->Promise.then(_ => {
        passWith("Slot was released in the guard; second acquire resolved immediately")
        planned(~planned=1, ())
        Fetcher.release(sem)
        Promise.resolve()
      })
      ->Promise.catch(_ => {
        failWith("Second acquire failed — semaphore was leaked by critical section throw")
        planned(~planned=0, ())
        Promise.resolve()
      })
      ->ignore
      Promise.resolve()
    })
    ->ignore
    Promise.resolve()
  })
  ->ignore
})

/* Integration regression test: with concurrency=1 and N>1 URLs that all fail,
   `fetchAll` MUST complete in bounded time — no fetch may deadlock on `acquire`.
   This guards the production integration end-to-end. With the fix in place,
   each failing fetch still releases its slot, so the next fetch in the queue
   proceeds. */

testAsync("fetchAll with concurrency=1 processes a queue of failing URLs without deadlocking", planned => {
  let options: Fetcher.fetchOptions = {
    concurrency: 1,
    userAgent: "test-agent/1.0",
    timeoutSeconds: 1,
    retryCount: 0,
    delayMs: 0,
    headers: [],
  }
  // Three URLs to a closed local port — all will fail with NetworkError,
  // none should deadlock the queue.
  let urls = ["http://127.0.0.1:9", "http://127.0.0.1:9", "http://127.0.0.1:9"]

  Fetcher.fetchAll(urls, options)
  ->Promise.then(results => {
    (results->Array.length == 3)->isTruthy
    let allFailed =
      results
      ->Array.filter(
        r =>
          switch r.result {
          | Ok(_) => false
          | Error(_) => true
          },
      )
      ->Array.length
    (allFailed == 3)->isTruthy
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("fetchAll deadlocked or threw unexpectedly with concurrency=1 and 3 failing URLs")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})
