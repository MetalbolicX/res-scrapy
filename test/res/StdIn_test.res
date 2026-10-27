open Test
open Assertions
open StdIn

let isNoInput = e =>
  switch e {
  | NoInput(_) => true
  | _ => false
  }

let isEmptyContent = e =>
  switch e {
  | EmptyContent(_) => true
  | _ => false
  }

let isReadError = e =>
  switch e {
  | ReadError(_) => true
  | _ => false
  }

module Stream = NodeProcess.TestSupport
let wait = ms =>
  Promise.make((resolve, _) => {
    let _ = setTimeout(() => resolve(), ms)
  })

let streamCase = (
  ~input="",
  ~cap=4,
  ~tty=false,
  ~failAt=?,
  ~finish=true,
  ~streamError=false,
  ~abort=false,
  ~expected,
  name,
) =>
  testAsync(name, planned => {
    let fixture = Stream.make(~tty, ~failAt?, ())
    let stream = Stream.stream(fixture)
    let settlements = ref(0)
    let run = async () => {
      let pending = readFromStream(
        ~stream,
        ~maxBytes=cap,
        ~timeoutMs=20,
        (),
      )->Promise.then(result => {
        settlements := settlements.contents + 1
        Promise.resolve(result)
      })
      if failAt->Option.isNone && !tty {
        if streamError {
          Stream.emitError(stream, "broken")
        } else {
          Stream.write(stream, input)
          if finish {
            Stream.end_(stream)
          }
        }
      }
      let result = try {Some(await pending)} catch {
      | _ => None
      }
      isTruthy(result == Some(expected))
      isIntEqualTo(1, settlements.contents)
      isIntEqualTo(0, Stream.listenerCount(stream, "data"))
      isIntEqualTo(1, Stream.listenerCount(stream, "end"))
      isIntEqualTo(1, Stream.listenerCount(stream, "error"))
      isTruthy(!abort || Stream.paused(stream))
      let ends = Stream.sentinelEnds(fixture)
      let errors = Stream.sentinelErrors(fixture)
      Stream.lateEvents(stream)
      await wait(30)
      isIntEqualTo(1, settlements.contents)
      isIntEqualTo(ends + 1, Stream.sentinelEnds(fixture))
      isIntEqualTo(errors + 1, Stream.sentinelErrors(fixture))
      isIntEqualTo(0, Stream.listenerCount(stream, "data"))
      isIntEqualTo(1, Stream.listenerCount(stream, "end"))
      isIntEqualTo(1, Stream.listenerCount(stream, "error"))
      isTruthy(!tty || Stream.resumes(fixture) == 0)
      Stream.destroy(stream)
      planned(~planned=13, ())
    }
    run()
    ->Promise.catch(_ => {
      Stream.destroy(stream)
      failWith("Stream lifecycle test rejected")
      planned(~planned=0, ())
      Promise.resolve()
    })
    ->ignore
  })

streamCase(~input="éé", ~expected=Ok("éé"), "stdin UTF8 exactly four bytes fits cap four")
streamCase(
  ~input="éé",
  ~cap=3,
  ~finish=false,
  ~abort=true,
  ~expected=Error(ReadError("Stdin exceeds maximum size of 3 bytes")),
  "stdin UTF8 exceeds cap three with producer open",
)
streamCase(~input="abcd", ~expected=Ok("abcd"), "stdin ASCII exact cap succeeds")
streamCase(
  ~input="abcde",
  ~finish=false,
  ~abort=true,
  ~expected=Error(ReadError("Stdin exceeds maximum size of 4 bytes")),
  "stdin overflow pauses and detaches open producer",
)
streamCase(
  ~finish=false,
  ~abort=true,
  ~expected=Error(ReadError("Timed out after 0 seconds while reading stdin")),
  "stdin timeout pauses and detaches open producer",
)
streamCase(
  ~tty=true,
  ~expected=Error(NoInput("No HTML input provided via stdin")),
  "stdin TTY preserves NoInput",
)
streamCase(
  ~input="  ",
  ~expected=Error(EmptyContent("Empty HTML content received from stdin")),
  "stdin whitespace preserves EmptyContent",
)
streamCase(~input=" a ", ~expected=Ok("a"), "stdin success trims boundaries")
streamCase(
  ~streamError=true,
  ~abort=true,
  ~expected=Error(ReadError("Error reading stdin: broken")),
  "stdin stream error resolves ReadError and cleans timer",
)
["encoding", "end", "resume"]->Array.forEach(stage =>
  streamCase(
    ~failAt=stage,
    ~abort=true,
    ~expected=Error(ReadError(`Error initializing stdin read: fixture ${stage}`)),
    `stdin setup ${stage} resolves ReadError not rejection`,
  )
)

test("hasStdinDataFrom treats a TTY as no piped input", () => {
  isTruthy(hasStdinDataFrom(Some(true)) == false)
})

test("hasStdinDataFrom treats a non-TTY stream as piped input", () => {
  isTruthy(hasStdinDataFrom(Some(false)) == true)
})

test("hasStdinDataFrom treats an unknown TTY state as piped input", () => {
  isTruthy(hasStdinDataFrom(None) == true)
})

test("NoInput error message is descriptive", () => {
  let msg = "No HTML input provided via stdin"
  switch NoInput(msg) {
  | NoInput(m) => isTextEqualTo(msg, m)
  | _ => failWith("Expected NoInput variant")
  }
})

test("EmptyContent error message is descriptive", () => {
  let msg = "Empty HTML content received from stdin"
  switch EmptyContent(msg) {
  | EmptyContent(m) => isTextEqualTo(msg, m)
  | _ => failWith("Expected EmptyContent variant")
  }
})

test("ReadError error message includes context", () => {
  let msg = "Error reading stdin: something went wrong"
  switch ReadError(msg) {
  | ReadError(m) => isTextEqualTo(msg, m)
  | _ => failWith("Expected ReadError variant")
  }
})

test("stdInError variants can be discriminated cleanly", () => {
  let errors: array<stdInError> = [
    NoInput("no input"),
    EmptyContent("empty"),
    ReadError("read failed"),
  ]
  isIntEqualTo(3, Array.length(errors))
  isTruthy(errors->Array.map(isNoInput) == [true, false, false])
  isTruthy(errors->Array.map(isEmptyContent) == [false, true, false])
  isTruthy(errors->Array.map(isReadError) == [false, false, true])
})
