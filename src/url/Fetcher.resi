/**
  * Concurrent HTML fetcher with retry logic and semaphore-based concurrency control.
  *
  * Fetches multiple URLs in parallel with:
  * - Configurable concurrency cap (default 5, max 20)
  * - 3 retries with exponential backoff (1s, 2s, 4s) + jitter (±500ms)
  * - 30s timeout per request
  * - Optional proxy routing via EnvHttpProxyAgent when HTTP_PROXY/HTTPS_PROXY/ALL_PROXY are set
  * - Retry only on transient failures (network errors, timeouts, 429, 5xx)
  *
  * Uses `Promise.all` to collect all fetch results; each fetch always resolves with `result`.
  */

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

/**
  * @internal Exported for unit testing only.
  * Checks if an error is retryable (transient failure).
  */
let isRetryable: fetchError => bool

/**
  * @internal Exported for unit testing only.
  * Calculates exponential backoff delay for a retry attempt.
  */
let backoffDelay: int => int

/**
  * Fetches all URLs with concurrency control.
  */
let fetchAll: (array<string>, fetchOptions) => promise<array<fetchResult>>

/**
  * Converts a fetchError to a human-readable string.
  */
let fetchErrorToMessage: fetchError => string
