type fetchError =
  | NetworkError(string)
  | Timeout(string)
  | HttpError(int, string)
  | ParseError(string)

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
  * attempt=0 → 1s, attempt=1 → 2s, attempt=2 → 4s
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

let createEnvProxyDispatcher: unit => promise<option<NodeFetch.dispatcher>> = %raw(`async () => {
    const hasProxy = Boolean(
      process.env.HTTP_PROXY ||
      process.env.HTTPS_PROXY ||
      process.env.ALL_PROXY
    );
    if (!hasProxy) return undefined;
    try {
      const undici = await import('undici');
      return new undici.EnvHttpProxyAgent();
    } catch {
      console.error("Warning: HTTP_PROXY/HTTPS_PROXY/ALL_PROXY is set but undici is unavailable — proxy will be ignored. Install undici with: npm install undici");
      return undefined;
    }
  }`)

let proxyDispatcherPromise: ref<option<promise<option<NodeFetch.dispatcher>>>> = ref(None)

let getEnvProxyDispatcher = (): promise<option<NodeFetch.dispatcher>> =>
  switch proxyDispatcherPromise.contents {
  | Some(promise) => promise
  | None => {
      let promise = createEnvProxyDispatcher()
      proxyDispatcherPromise := Some(promise)
      promise
    }
  }

/**
  * Fetches a single URL with timeout and error handling.
  */
let fetchOnce: (
  string,
  string,
  int,
  array<(string, string)>,
) => promise<result<string, fetchError>> = async (url, userAgent, timeoutSeconds, headers) => {
  let timeoutMs = timeoutSeconds * 1000
  // Set up controller and timeout OUTSIDE try so timeoutId is accessible in catch.
  let controller = NodeFetch.AbortSignal.makeController()
  let timeoutId = setTimeout(() => {
    NodeFetch.AbortSignal.abort(controller)
  }, timeoutMs)

  let headerPairs = Array.concat([("User-Agent", userAgent)], headers)
  let dispatcher = await getEnvProxyDispatcher()
  let options: NodeFetch.options = {
    method: "GET",
    headers: Dict.fromArray(headerPairs),
    signal: NodeFetch.AbortSignal.signal(controller),
    ?dispatcher,
  }

  try {
    let response = await NodeFetch.fetch(url, Some(options))

    if response.ok {
      let html = await NodeFetch.text(response)
      clearTimeout(timeoutId)
      Ok(html)
    } else {
      clearTimeout(timeoutId)
      Error(HttpError(response.status, response.statusText))
    }
  } catch {
  | exn => {
      clearTimeout(timeoutId)
      let message = switch exn->JsExn.fromException {
      | Some(jsExn) => jsExn->JsExn.message->Option.getOr("Unknown error")
      | None => "Unknown error"
      }

      // Classify via the signal state, not the exception message text.
      let isAborted = NodeFetch.AbortSignal.aborted(NodeFetch.AbortSignal.signal(controller))
      classifyError(~message, ~isAborted, ~timeoutSeconds)
    }
  }
}

/**
  * Fetches a URL with retries.
  */
let fetchWithRetry: (
  string,
  string,
  int,
  int,
  array<(string, string)>,
) => promise<result<string, fetchError>> = async (
  url,
  userAgent,
  timeoutSeconds,
  retryCount,
  headers,
) => {
  let rec tryFetch = async (attempt: int, maxAttempts: int) => {
    let result = await fetchOnce(url, userAgent, timeoutSeconds, headers)

    switch result {
    | Ok(_) => result
    | Error(err) =>
      if attempt < maxAttempts && isRetryable(err) {
        let delayMs = backoffDelay(attempt)
        await delay(delayMs)
        await tryFetch(attempt + 1, maxAttempts)
      } else {
        result
      }
    }
  }

  await tryFetch(1, retryCount)
}

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
