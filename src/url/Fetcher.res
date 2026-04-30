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
  * Delays for the specified milliseconds.
  */
let delay: int => promise<unit> = ms =>
  Promise.make((resolve, _reject) => {
    let _timerId = setTimeout(() => resolve(), ms)
    ()
  })

let createEnvProxyDispatcher: unit => promise<option<NodeJsBinding.Fetch.dispatcher>> =
  %raw(`async () => {
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
      return undefined;
    }
  }`)

let proxyDispatcherPromise: ref<option<promise<option<NodeJsBinding.Fetch.dispatcher>>>> = ref(None)

let getEnvProxyDispatcher = (): promise<option<NodeJsBinding.Fetch.dispatcher>> =>
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
let fetchOnce: (string, string, int, array<(string, string)>) => promise<result<string, fetchError>> = async (url, userAgent, timeoutSeconds, headers) => {
  let timeoutMs = timeoutSeconds * 1000
  // Set up controller and timeout OUTSIDE try so timeoutId is accessible in catch.
  let controller = NodeJsBinding.Fetch.AbortSignal.makeController()
  let timeoutId = setTimeout(() => {
    NodeJsBinding.Fetch.AbortSignal.abort(controller)
  }, timeoutMs)

  let headerPairs = Array.concat([("User-Agent", userAgent)], headers)
  let dispatcher = await getEnvProxyDispatcher()
  let options: NodeJsBinding.Fetch.options = {
    method: "GET",
    headers: Dict.fromArray(headerPairs),
    signal: NodeJsBinding.Fetch.AbortSignal.signal(controller),
    ?dispatcher,
  }

  try {
    let response = await NodeJsBinding.Fetch.fetch(url, Some(options))
    clearTimeout(timeoutId)

    if response.ok {
      let html = await NodeJsBinding.Fetch.text(response)
      Ok(html)
    } else {
      Error(HttpError(response.status, response.statusText))
    }
  } catch {
  | exn => {
      clearTimeout(timeoutId)
      let message = switch exn->JsExn.fromException {
      | Some(jsExn) => jsExn->JsExn.message->Option.getOr("Unknown error")
      | None => "Unknown error"
      }

      // Detect timeout
      if String.includes(message, "abort") || String.includes(message, "timeout") {
        Error(Timeout(`timeout after ${Int.toString(timeoutMs / 1000)}s`))
      } else {
        Error(NetworkError(message))
      }
    }
  }
}

/**
  * Fetches a URL with retries.
  */
let fetchWithRetry: (string, string, int, int, array<(string, string)>) => promise<result<string, fetchError>> = async (url, userAgent, timeoutSeconds, retryCount, headers) => {
  let rec tryFetch = async (attempt: int, maxAttempts: int) => {
    let result = await fetchOnce(url, userAgent, timeoutSeconds, headers)
    
    switch result {
    | Ok(_) => result
    | Error(err) => {
        if attempt < maxAttempts && isRetryable(err) {
          let delayMs = backoffDelay(attempt)
          await delay(delayMs)
          await tryFetch(attempt + 1, maxAttempts)
        } else {
          result
        }
      }
    }
  }
  
  await tryFetch(1, retryCount)
}

/**
  * Semaphore to limit concurrency.
  */
type semaphore = {
  mutable available: int,
  mutable waiting: array<unit => unit>,
}

let makeSemaphore = (max: int) => {
  available: max,
  waiting: [],
}

let acquire = (sem: semaphore) =>
  Promise.make((resolve, _reject) => {
    if sem.available > 0 {
      sem.available = sem.available - 1
      resolve()
    } else {
      sem.waiting->Array.push(() => resolve())
    }
  })

let release = (sem: semaphore) => {
  switch sem.waiting->Array.shift {
  | Some(resolver) => resolver()
  | None => sem.available = sem.available + 1
  }
}

type startLimiter = {
  mutable nextStartAt: float,
  delayMs: int,
}

let makeStartLimiter = (delayMs: int): startLimiter => {
  nextStartAt: 0.0,
  delayMs,
}

let acquireStartSlot = async (limiter: startLimiter) => {
  if limiter.delayMs <= 0 {
    ()
  } else {
    let now = NodeJsBinding.Performance.now()
    let scheduledStart = max(limiter.nextStartAt, now)
    let waitMs = scheduledStart -. now
    limiter.nextStartAt = scheduledStart +. Float.fromInt(limiter.delayMs)
    if waitMs > 0.0 {
      await delay(waitMs->Float.toInt)
    }
  }
}

/**
  * Fetches all URLs with concurrency control.
  */
let fetchAll: (array<string>, fetchOptions) => promise<array<fetchResult>> = async (urls, options) => {
  let concurrency = min(options.concurrency, 20) // Hard cap at 20
  let sem = makeSemaphore(concurrency)
  let limiter = makeStartLimiter(options.delayMs)

  let fetchWithSemaphore = async url => {
    await acquire(sem)
    await acquireStartSlot(limiter)
    let result = await fetchWithRetry(url, options.userAgent, options.timeoutSeconds, options.retryCount, options.headers)
    release(sem)
    {url, result}
  }

  let promises = urls->Array.map(fetchWithSemaphore)
  let results = await Promise.all(promises)
  results
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
