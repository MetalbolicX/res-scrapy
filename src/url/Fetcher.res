type fetchError =
  | NetworkError(string)
  | Timeout(string)
  | HttpError(int, string)
  | ParseError(string)

type attemptOutcome = {result: result<string, fetchError>, retryAfter: option<string>}
let outcome = result => {result, retryAfter: None}

type fetchResult = {
  url: string,
  result: result<string, fetchError>,
}

type fetchOptions = {
  concurrency: int,
  userAgent: string,
  timeoutSeconds: int,
  retryCount: int,
  delayMs: int,
  headers: array<(string, string)>,
}

// User-supplied headers go to the requested URL and same-origin redirects only; cross-origin redirects receive User-Agent only.

/** Base delay for exponential backoff (1 second). */
let baseDelayMs = 1000

/** Random jitter range in milliseconds (±500ms). */
let jitterMs = 500

/**
  * Generates a random jitter between -jitterMs and +jitterMs.
  */
let randomJitter: unit => int = () => {
  let random = Math.random() // 0.0 to 1.0
  let range = jitterMs * 2
  let offset = Float.toInt(random *. Float.fromInt(range)) - jitterMs
  offset
}

/**
  * Calculates exponential backoff delay for retry attempt.
  * The first retry waits backoffDelay(1) ≈ 2s (±500ms jitter); the 1s base applies only if a caller starts at attempt=0.
  */
let backoffDelay: int => int = attempt => {
  let exponent = Float.fromInt(attempt)
  let multiplier = Math.pow(2.0, ~exp=exponent)
  let delay = (Float.fromInt(baseDelayMs) *. multiplier)->Float.toInt
  max(0, delay + randomJitter())
}

/**
  * Checks if an error is retryable.
  */
let isRetryable: fetchError => bool = err =>
  switch err {
  | NetworkError(_) => true
  | Timeout(_) => true
  | HttpError(429, _) => true // Rate limited
  | HttpError(status, _) if status >= 500 => true // Server errors
  | HttpError(_, _) => false // Other 4xx errors
  | ParseError(_) => false
  }

/**
  * Classifies a fetch failure based on whether the request signal was aborted
  * (e.g. by the timeout controller). Replaces fragile string-matching on the
  * exception message, which broke when the underlying runtime changed its
  * error text.
  */
let classifyError = (~message: string, ~isAborted: bool, ~timeoutSeconds: int): result<
  'a,
  fetchError,
> =>
  if isAborted {
    Error(Timeout(`timeout after ${Int.toString(timeoutSeconds)}s`))
  } else {
    Error(NetworkError(message))
  }

/**
  * Delays for the specified milliseconds.
  */
let delay: int => promise<unit> = ms =>
  Promise.make((resolve, _reject) => {
    let _timerId = setTimeout(() => resolve(), ms)
  })

let createEnvProxyDispatcher = NodeUndiciBinding.createEnvProxyDispatcher

let proxyDispatcherPromise: ref<option<promise<option<NodeUndiciBinding.dispatcher>>>> = ref(None)

let getEnvProxyDispatcher = (): promise<option<NodeUndiciBinding.dispatcher>> =>
  switch proxyDispatcherPromise.contents {
  | Some(promise) => promise
  | None => {
      let promise = createEnvProxyDispatcher()
      proxyDispatcherPromise := Some(promise)
      promise
    }
  }

/** Follows redirects while restricting user headers to the requested origin. */
let rec fetchWithRedirects = async (
  ~rawFetch: (string, option<NodeFetch.options>) => promise<NodeFetch.response>,
  ~url: string,
  ~headerPairs: array<(string, string)>,
  ~userAgent: string,
  ~controller: NodeFetch.AbortSignal.controller,
  ~requests: int,
  ~maxBodyBytes: int,
): attemptOutcome => {
  if requests >= 20 {
    outcome(Error(NetworkError("Too many redirects (20)")))
  } else {
    let options: NodeFetch.options = {
      method: "GET",
      headers: Dict.fromArray(headerPairs),
      signal: NodeFetch.AbortSignal.signal(controller),
      redirect: "manual",
    }
    let response = await rawFetch(url, Some(options))
    let isRedirect =
      response.status == 301 ||
      response.status == 302 ||
      response.status == 303 ||
      response.status == 307 ||
      response.status == 308
    switch (isRedirect, NodeFetch.getHeader(response.headers, "location")) {
    | (true, Some(location)) => {
        await NodeFetch.cancelBody(response)
        let current = NodeUrl.make(url, None)
        let next = NodeUrl.make(location, Some(url))
        let nextHeaders = if current.origin == next.origin {
          headerPairs
        } else {
          [("User-Agent", userAgent)]
        }
        await fetchWithRedirects(
          ~rawFetch,
          ~url=next.href,
          ~headerPairs=nextHeaders,
          ~userAgent,
          ~controller,
          ~requests=requests + 1,
          ~maxBodyBytes,
        )
      }
    | _ =>
      if response.ok {
        let exceedsLimit = size => size > Float.fromInt(maxBodyBytes)
        let declaredTooLarge =
          NodeFetch.getHeader(response.headers, "content-length")
          ->Option.flatMap(NodeFetch.decimalLength)
          ->Option.map(exceedsLimit)
          ->Option.getOr(false)
        let sizeError = () => Error(
          ParseError(`Response exceeds maximum size of ${SizeLimit.describe(maxBodyBytes)}`),
        )
        let rejectSize = async () => {
          await NodeFetch.cancelBody(response)
          outcome(sizeError())
        }
        if declaredTooLarge {
          await rejectSize()
        } else {
          let bytes = await NodeFetch.readBodyWithin(response, Float.fromInt(maxBodyBytes))
          switch bytes {
          | OverLimit => outcome(sizeError())
          | Within(bytes) =>
            outcome(
              Ok(
                NodeFetch.decodeHtml(bytes, NodeFetch.getHeader(response.headers, "content-type")),
              ),
            )
          }
        }
      } else {
        let retryAfter = if response.status == 429 || response.status == 503 {
          NodeFetch.getHeader(response.headers, "retry-after")
        } else {
          None
        }
        await NodeFetch.cancelBody(response)
        {result: Error(HttpError(response.status, response.statusText)), retryAfter}
      }
    }
  }
}

/** Internal testing seam; public wrappers retain their existing signatures. */
let fetchOnceDetailedWithRawFetch = async (
  ~maxBodyBytes=SizeLimit.maxInputBytes,
  rawFetch,
  url,
  userAgent,
  timeoutSeconds,
  headers,
) => {
  let timeoutMs = timeoutSeconds * 1000
  let controller = NodeFetch.AbortSignal.makeController()
  let timeoutId = setTimeout(() => NodeFetch.AbortSignal.abort(controller), timeoutMs)
  let headerPairs = Array.concat([("User-Agent", userAgent)], headers)

  try {
    let result = await fetchWithRedirects(
      ~rawFetch,
      ~url,
      ~headerPairs,
      ~userAgent,
      ~controller,
      ~requests=0,
      ~maxBodyBytes,
    )
    clearTimeout(timeoutId)
    result
  } catch {
  | exn => {
      clearTimeout(timeoutId)
      let message = switch exn->JsExn.fromException {
      | Some(jsExn) => jsExn->JsExn.message->Option.getOr("Unknown error")
      | None => "Unknown error"
      }
      let isAborted = NodeFetch.AbortSignal.aborted(NodeFetch.AbortSignal.signal(controller))
      outcome(classifyError(~message, ~isAborted, ~timeoutSeconds))
    }
  }
}

let fetchOnceWithBodyLimit = async (
  ~maxBodyBytes=SizeLimit.maxInputBytes,
  rawFetch,
  url,
  userAgent,
  timeoutSeconds,
  headers,
) => {
  let detail = await fetchOnceDetailedWithRawFetch(
    ~maxBodyBytes,
    rawFetch,
    url,
    userAgent,
    timeoutSeconds,
    headers,
  )
  detail.result
}

let fetchOnceWithRawFetch = (rawFetch, url, userAgent, timeoutSeconds, headers) =>
  fetchOnceWithBodyLimit(rawFetch, url, userAgent, timeoutSeconds, headers)

/** Fetches a single URL with proxy routing and one timeout across all hops. */
let fetchOnceDetailed = (url, userAgent, timeoutSeconds, headers) => {
  let rawFetch = async (requestUrl, options) => {
    let dispatcher = await getEnvProxyDispatcher()
    let optionsWithDispatcher: option<NodeFetch.options> = switch (dispatcher, options) {
    | (Some(d), Some(baseOptions)) => Some({...baseOptions, dispatcher: Obj.magic(d)})
    | (Some(d), None) => {
        let dispatcherOptions: NodeFetch.options = {dispatcher: Obj.magic(d)}
        Some(dispatcherOptions)
      }
    | (None, Some(baseOptions)) => Some(baseOptions)
    | (None, None) => None
    }
    await NodeFetch.fetch(requestUrl, optionsWithDispatcher)
  }
  fetchOnceDetailedWithRawFetch(rawFetch, url, userAgent, timeoutSeconds, headers)
}

let fetchOnce = async (url, userAgent, timeoutSeconds, headers) => {
  let detail = await fetchOnceDetailed(url, userAgent, timeoutSeconds, headers)
  detail.result
}

/** Finite milliseconds are clamped before conversion to a ReScript int. */
let retryAfterDelay = (~retryAfter, ~nowMs, ~backoffMs) =>
  switch retryAfter->Option.flatMap(value => NodeFetch.retryAfterMilliseconds(value, nowMs)) {
  | Some(ms) => Float.toInt(max(0.0, min(60000.0, ms)))
  | None => backoffMs
  }

/** One retry loop owns the budget and per-attempt hint lifetime. */
let retryDetailed = async (~attempt, ~sleep, ~nowMs, ~backoff, ~retryCount) => {
  let rec tryFetch = async attemptNumber => {
    let detail: attemptOutcome = await attempt()
    switch detail.result {
    | Ok(_) => detail.result
    | Error(err) =>
      if attemptNumber < retryCount && isRetryable(err) {
        let delayMs = retryAfterDelay(
          ~retryAfter=detail.retryAfter,
          ~nowMs=nowMs(),
          ~backoffMs=backoff(attemptNumber),
        )
        await sleep(delayMs)
        await tryFetch(attemptNumber + 1)
      } else {
        detail.result
      }
    }
  }
  await tryFetch(1)
}

/** Preserve the existing result-only testing interface. */
let retryWithAttempt = (~attempt, ~sleep, ~retryCount) =>
  retryDetailed(
    ~attempt=async () => outcome(await attempt()),
    ~sleep,
    ~nowMs=NodeFetch.nowMs,
    ~backoff=backoffDelay,
    ~retryCount,
  )

/** Injectable transport uses the exact detailed path used in production. */
let retryWithRawFetch = (~rawFetch, ~sleep, ~nowMs, ~backoff, ~retryCount) =>
  retryDetailed(
    ~attempt=() => fetchOnceDetailedWithRawFetch(rawFetch, "http://example.test/", "agent", 5, []),
    ~sleep,
    ~nowMs,
    ~backoff,
    ~retryCount,
  )

/** Do not project away Retry-After before entering the production retry loop. */
let fetchWithRetry = (url, userAgent, timeoutSeconds, retryCount, headers) =>
  retryDetailed(
    ~attempt=() => fetchOnceDetailed(url, userAgent, timeoutSeconds, headers),
    ~sleep=delay,
    ~nowMs=NodeFetch.nowMs,
    ~backoff=backoffDelay,
    ~retryCount,
  )

/**
  * Fetches all URLs with concurrency control.
  */
let fetchAll: (array<string>, fetchOptions) => promise<array<fetchResult>> = async (
  urls,
  options,
) => {
  let concurrency = min(options.concurrency, 20) // Hard cap at 20
  let sem = Semaphore.make(concurrency)
  let limiter = StartLimiter.make(~delayMs=options.delayMs)

  let fetchWithSemaphore = async url => {
    await Semaphore.acquire(sem)
    // NOTE: ReScript v12 has no `try/finally`. We use `try/catch` to convert
    // any escaped exception into `Error(exn)`, then `Semaphore.release(sem)` is called
    // unconditionally below — guaranteeing the slot is returned on every
    // exit path (success OR exception). The exception is then re-thrown via
    // `throw(exn)` so the outer `Promise.catch` in `fetchAll` still observes
    // it as before.
    let outcome = try {
      let result = await StartLimiter.acquireStartSlot(limiter)->Promise.then(_ =>
        fetchWithRetry(
          url,
          options.userAgent,
          options.timeoutSeconds,
          options.retryCount,
          options.headers,
        )
      )
      Ok({url, result})
    } catch {
    | exn => Error(exn)
    }
    Semaphore.release(sem)
    switch outcome {
    | Ok(fetchResult) => fetchResult
    | Error(exn) => throw(exn)
    }
  }

  let promises = urls->Array.map(url =>
    fetchWithSemaphore(url)->Promise.catch(exn =>
      Promise.resolve({
        url,
        result: Error(NetworkError(`Unexpected rejection: ${ExnUtils.message(exn)}`)),
      })
    )
  )
  await Promise.all(promises)
}

/**
  * Converts a fetchError to a human-readable string.
  */
let fetchErrorToMessage: fetchError => string = err => {
  switch err {
  | NetworkError(msg) => `Network error: ${msg}`
  | Timeout(msg) => `Timeout: ${msg}`
  | HttpError(status, msg) => `HTTP ${Int.toString(status)}: ${msg}`
  | ParseError(msg) => `Parse error: ${msg}`
  }
}
