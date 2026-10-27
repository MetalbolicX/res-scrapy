open Test
open Assertions

testAsync("acquireStartSlot spaces sequential request starts by the configured delay", done_ => {
  let limiter = StartLimiter.make(~delayMs=50)
  let startedAt = NodePerformance.now()
  let run = async () => {
    let _ = await StartLimiter.acquireStartSlot(limiter)
    let first = NodePerformance.now()
    let _ = await StartLimiter.acquireStartSlot(limiter)
    let second = NodePerformance.now()
    let _ = await StartLimiter.acquireStartSlot(limiter)
    let third = NodePerformance.now()
    isTruthy(
      second -. first >= 40.0,
      ~message=`second start gap ${Float.toString(second -. first)}ms is below 40ms`,
    )
    isTruthy(
      third -. second >= 40.0,
      ~message=`third start gap ${Float.toString(third -. second)}ms is below 40ms`,
    )
    // Reservations overlap, so three starts cost about two delays, not three full waits.
    isTruthy(
      third -. startedAt < 1000.0,
      ~message=`three starts took ${Float.toString(third -. startedAt)}ms`,
    )
    done_(~planned=3, ())
  }
  run()->ignore
})

testAsync("acquireStartSlot with zero delay resolves every acquisition", done_ => {
  let limiter = StartLimiter.make(~delayMs=0)
  let completed = ref(0)
  let run = async () => {
    let _ = await StartLimiter.acquireStartSlot(limiter)
    completed := completed.contents + 1
    let _ = await StartLimiter.acquireStartSlot(limiter)
    completed := completed.contents + 1
    let _ = await StartLimiter.acquireStartSlot(limiter)
    completed := completed.contents + 1
    isIntEqualTo(3, completed.contents)
    done_(~planned=1, ())
  }
  run()->ignore
})
