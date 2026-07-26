/**
 * StartLimiter — enforces a minimum delay between the start of consecutive
 * fetch operations (rate-limiting at start-time, not completion-time).
 *
 * Each `acquireStartSlot` call enforces that at least `delayMs` milliseconds
 * have elapsed since the last start. If called too soon, it waits.
 * If `delayMs <= 0`, the slot is granted immediately.
 *
 * Generic enough to be used by any rate-limited queue (not coupled to HTTP).
 */
type t = {
  mutable nextStartAt: float,
  delayMs: int,
}

let make = (~delayMs: int): t => {
  nextStartAt: 0.0,
  delayMs,
}

let delay: int => promise<unit> = ms =>
  Promise.make((resolve, _reject) => {
    let _timerId = setTimeout(() => resolve(), ms)
  })

let acquireStartSlot = async (limiter: t): Promise.t<unit> => {
  if limiter.delayMs <= 0 {
    Promise.resolve()
  } else {
    let now = NodePerformance.now()
    let scheduledStart = max(limiter.nextStartAt, now)
    let waitMs = scheduledStart -. now
    limiter.nextStartAt = scheduledStart +. Float.fromInt(limiter.delayMs)
    if waitMs > 0.0 {
      await delay(waitMs->Float.toInt)
    }
    Promise.resolve()
  }
}
