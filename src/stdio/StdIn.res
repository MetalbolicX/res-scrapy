type stdInError =
  | NoInput(string)
  | EmptyContent(string)
  | ReadError(string)

type timeoutId
external setTimeoutImpl: (unit => unit, int) => timeoutId = "setTimeout"
let startTimeout: (int, unit => unit) => timeoutId = (ms, cb) => setTimeoutImpl(cb, ms)
external clearTimeoutImpl: timeoutId => unit = "clearTimeout"
let clearTimeout_ = clearTimeoutImpl

/** Maximum UTF-8 stdin size in bytes (50 MiB). */
let maxStdinBytes =
  50 * 1024 * 1024
/** Maximum time to wait for stdin completion (30 seconds). */
let maxStdinMs =
  30 * 1000

let hasStdinData: unit => bool = () => NodeProcess.stdin.isTTY != Some(true)

/** The caller owns the stream. Remove only this reader's callbacks on every
    terminal path; pause aborted reads without destroying shared stdin. */
let readFromStream = (
  ~stream: NodeProcess.stdInput,
  ~maxBytes=maxStdinBytes,
  ~timeoutMs=maxStdinMs,
  (),
) => {
  Promise.make((resolve, _reject) => {
    open NodeProcess
    let chunks = ref([])
    let totalBytes = ref(0)
    let settled = ref(false)
    let timer = ref(None)
    let dataListener: ref<option<string => unit>> = ref(None)
    let endListener: ref<option<unit => unit>> = ref(None)
    let errorListener: ref<option<JsExn.t => unit>> = ref(None)
    let complete = (~abort=false, result) => {
      if !settled.contents {
        settled := true
        timer.contents->Option.forEach(clearTimeout_)
        timer := None
        if abort {
          stream->pause
        }
        dataListener.contents->Option.forEach(cb => stream->removeDataListener(cb))
        endListener.contents->Option.forEach(cb => stream->removeEndListener(cb))
        errorListener.contents->Option.forEach(cb => stream->removeErrorListener(cb))
        chunks := []
        resolve(result)
      }
    }
    try {
      if stream.isTTY == Some(true) {
        complete(Error(NoInput("No HTML input provided via stdin")))
      } else {
        let onData = chunk => {
          if !settled.contents {
            let nextSize = totalBytes.contents + utf8ByteLength(chunk)
            if nextSize > maxBytes {
              complete(
                ~abort=true,
                Error(
                  ReadError(
                    `Stdin exceeds maximum size of ${Int.toString(maxBytes / 1024 / 1024)} MB`,
                  ),
                ),
              )
            } else {
              totalBytes := nextSize
              chunks.contents->Array.push(chunk)
            }
          }
        }
        let onEnd = () => {
          if !settled.contents {
            let content = chunks.contents->Array.join("")->String.trim
            complete(
              content == ""
                ? Error(EmptyContent("Empty HTML content received from stdin"))
                : Ok(content),
            )
          }
        }
        let onError = error => {
          if !settled.contents {
            let message = error->JsExn.message->Option.getOr("Unknown error")
            complete(~abort=true, Error(ReadError(`Error reading stdin: ${message}`)))
          }
        }
        dataListener := Some(onData)
        endListener := Some(onEnd)
        errorListener := Some(onError)
        stream->setEncoding("utf8")
        timer :=
          Some(
            startTimeout(timeoutMs, () => {
              complete(
                ~abort=true,
                Error(
                  ReadError(
                    `Timed out after ${Int.toString(timeoutMs / 1000)} seconds while reading stdin`,
                  ),
                ),
              )
            }),
          )
        stream->NodeProcess.onData(onData)
        stream->NodeProcess.onEnd(onEnd)
        stream->NodeProcess.onError(onError)
        if !settled.contents {
          stream->resume
        }
      }
    } catch {
    | exn => {
        let message = switch exn->JsExn.fromException {
        | Some(error) => error->JsExn.message->Option.getOr("Unknown error")
        | None => "Unknown error"
        }
        complete(~abort=true, Error(ReadError(`Error initializing stdin read: ${message}`)))
      }
    }
  })
}

let readFromStdin: unit => promise<Result.t<string, stdInError>> = () =>
  readFromStream(~stream=NodeProcess.stdin, ())
