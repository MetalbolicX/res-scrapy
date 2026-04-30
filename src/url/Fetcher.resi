/**
  * Concurrent HTML fetcher with retry logic and semaphore-based concurrency control.
  *
  * Fetches multiple URLs in parallel with:
  * - Configurable concurrency cap (default 5, max 20)
  * - 3 retries with exponential backoff (1s, 2s, 4s) + jitter (±500ms)
  * - 30s timeout per request
  * - Retry only on transient failures (network errors, timeouts, 429, 5xx)
  *
  * Uses `Promise.allSettled` to ensure all fetches complete regardless of individual failures.
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
