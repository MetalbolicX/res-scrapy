/**
  * Unit coverage for `NodeProcess.exitWhenFlushed`.
  *
  * Fatal error and signal handlers exit the process directly, which can drop
  * bytes still buffered in an async stdout pipe. The helper must flush first,
  * bound the wait with a grace period, and run the exit callback exactly once.
  *
  * Fake streams keep the real `process.stdout` and the real process untouched.
  */
open Test
open Assertions

/** Fake stream shape mirroring the minimal `writable` surface bound in
    src/bindings/NodeProcess.res. */
type fakeStream = {
  writableLength: int,
  write: (string, unit => unit) => bool,
}

type writeRecorder = {
  mutable writes: int,
  mutable lastChunk: option<string>,
  mutable pending: option<unit => unit>,
}

let makeRecorder = (): writeRecorder => {writes: 0, lastChunk: None, pending: None}

let fakeStream = (~buffered: int, recorder: writeRecorder): NodeProcess.writable => {
  let stream: fakeStream = {
    writableLength: buffered,
    write: (chunk, cb) => {
      recorder.writes = recorder.writes + 1
      recorder.lastChunk = Some(chunk)
      recorder.pending = Some(cb)
      true
    },
  }
  Obj.magic(stream)
}

let makeExitRecorder = () => {
  let codes = ref([])
  let record = (code: int) => codes := codes.contents->Array.concat([code])
  (codes, record)
}

let pendingCallback = (recorder: writeRecorder): (unit => unit) =>
  switch recorder.pending {
  | Some(cb) => cb
  | None =>
    failWith("expected the helper to register a buffered write callback")
    () => ()
  }

let wait = ms =>
  Promise.make((resolve, _reject) => {
    let _ = setTimeout(() => resolve(), ms)
  })

test("empty buffer exits synchronously without writing", () => {
  let recorder = makeRecorder()
  let stream = fakeStream(~buffered=0, recorder)
  let (codes, exitFn) = makeExitRecorder()

  NodeProcess.exitWhenFlushed(stream, exitFn, 20, 130)

  isIntEqualTo(1, codes.contents->Array.length)
  isIntEqualTo(130, codes.contents->Array.get(0)->Option.getWithDefault(-1))
  isIntEqualTo(0, recorder.writes)
  switch recorder.pending {
  | Some(_) => failWith("write must not run when nothing is buffered")
  | None => ()
  }
})

test("buffered bytes exit only after the flush callback runs", () => {
  let recorder = makeRecorder()
  let stream = fakeStream(~buffered=42, recorder)
  let (codes, exitFn) = makeExitRecorder()

  NodeProcess.exitWhenFlushed(stream, exitFn, 1000, 1)

  isIntEqualTo(0, codes.contents->Array.length)
  isIntEqualTo(1, recorder.writes)
  isTextEqualTo("", recorder.lastChunk->Option.getWithDefault("<no chunk>"))

  pendingCallback(recorder)()

  isIntEqualTo(1, codes.contents->Array.length)
  isIntEqualTo(1, codes.contents->Array.get(0)->Option.getWithDefault(-1))
})

testAsync("grace period exits once when the flush callback never runs", planned => {
  let recorder = makeRecorder()
  let stream = fakeStream(~buffered=8, recorder)
  let (codes, exitFn) = makeExitRecorder()

  NodeProcess.exitWhenFlushed(stream, exitFn, 20, 143)
  isIntEqualTo(0, codes.contents->Array.length)

  let run = async () => {
    await wait(60)
    isIntEqualTo(1, codes.contents->Array.length)
    isIntEqualTo(143, codes.contents->Array.get(0)->Option.getWithDefault(-1))
    planned(~planned=3, ())
  }

  run()
  ->Promise.catch(_ => {
    failWith("grace period test rejected")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("a flush callback after the grace period does not exit twice", planned => {
  let recorder = makeRecorder()
  let stream = fakeStream(~buffered=8, recorder)
  let (codes, exitFn) = makeExitRecorder()

  NodeProcess.exitWhenFlushed(stream, exitFn, 20, 143)

  let run = async () => {
    await wait(60)
    isIntEqualTo(1, codes.contents->Array.length)

    pendingCallback(recorder)()
    await wait(20)
    isIntEqualTo(1, codes.contents->Array.length)
    isIntEqualTo(143, codes.contents->Array.get(0)->Option.getWithDefault(-1))
    planned(~planned=3, ())
  }

  run()
  ->Promise.catch(_ => {
    failWith("late flush callback test rejected")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})
