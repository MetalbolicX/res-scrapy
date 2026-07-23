/**
 * Semaphore — a classic Dijkstra semaphore for bounded concurrency.
 *
 * Tracks available slots and a queue of waiting callbacks.
 * `acquire` resolves when a slot is available; `release` frees one slot
 * and dispatches the next waiter if any exist.
 *
 * Generic enough to be used by any concurrent subsystem (not coupled to HTTP).
 */
module Iter = NodeJsBinding.Iter

type t = {
  mutable available: int,
  mutable waiting: array<unit => unit>,
}

let make = (max: int): t => {
  available: max,
  waiting: [],
}

let acquire = (sem: t): promise<unit> =>
  Promise.make((resolve, _reject) => {
    if sem.available > 0 {
      sem.available = sem.available - 1
      resolve()
    } else {
      sem.waiting->Array.push(() => resolve())
    }
  })

let release = (sem: t): unit => {
  switch sem.waiting->Array.shift {
  | Some(resolver) => resolver()
  | None => sem.available = sem.available + 1
  }
}
