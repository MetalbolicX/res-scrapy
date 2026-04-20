type stdInError =
  | NoInput(string)
  | EmptyContent(string)
  | ReadError(string)

type timeoutId

@new external makeError: string => JsExn.t = "Error"

let startTimeout: (int, unit => unit) => timeoutId = %raw(`(ms, cb) => setTimeout(cb, ms)`)
let clearTimeout_: timeoutId => unit = %raw(`id => clearTimeout(id)`)

/** Maximum stdin size in bytes (50 MB). Prevents memory exhaustion from
  * unexpectedly large inputs. */
let maxStdinBytes = 50 * 1024 * 1024

/** Maximum time to wait for stdin completion (30 seconds). */
let maxStdinMs = 30 * 1000

let hasStdinData: unit => bool = () => {
  open NodeJsBinding.Process
  switch stdin.isTTY {
  | Some(true) => false
  | _ => true
  }
}

let readFromStdin: unit => promise<Result.t<string, stdInError>> = () => {
  Promise.make((resolve, reject) => {
    let chunks = ref([])
    let totalBytes = ref(0)
    let settled = ref(false)

    let complete = (result: Result.t<string, stdInError>) => {
      if !settled.contents {
        settled := true
        resolve(result)
      }
    }

    if !hasStdinData() {
      complete(Result.Error(NoInput("No HTML input provided via stdin")))
    } else {
      try {
        open NodeJsBinding.Process

        stdin->setEncoding("utf8")

        let timer = startTimeout(maxStdinMs, () => {
          complete(
            Result.Error(
              ReadError(
                `Timed out after ${Int.toString(maxStdinMs / 1000)} seconds while reading stdin`,
              ),
            ),
          )
        })

        let completeWithCleanup = (result: Result.t<string, stdInError>) => {
          clearTimeout_(timer)
          complete(result)
        }

        stdin->onData(chunk => {
          if !settled.contents {
            let nextSize = totalBytes.contents + String.length(chunk)
            if nextSize > maxStdinBytes {
              completeWithCleanup(
                Result.Error(
                  ReadError(
                    `Stdin exceeds maximum size of ${Int.toString(maxStdinBytes / 1024 / 1024)} MB`,
                  ),
                ),
              )
            } else {
              totalBytes := nextSize
              chunks.contents->Array.push(chunk)
            }
          }
        })

        stdin->onEnd(() => {
          if !settled.contents {
            let content = chunks.contents->Array.join("")->String.trim
            switch content->String.length {
            | 0 =>
              completeWithCleanup(Result.Error(EmptyContent("Empty HTML content received from stdin")))
            | _ => completeWithCleanup(Result.Ok(content))
            }
          }
        })

        stdin->onError(error => {
          if !settled.contents {
            let errorMessage = switch error->JsExn.message {
            | Some(msg) => msg
            | None => "Unknown error"
            }

            completeWithCleanup(Result.Error(ReadError(`Error reading stdin: ${errorMessage}`)))
          }

          ()
        })

        stdin->resume
      } catch {
      | exn => {
          if !settled.contents {
            let errorMessage = switch exn->JsExn.fromException {
            | Some(jsExn) => jsExn->JsExn.message->Option.getOr("Unknown error")
            | None => "Unknown error"
            }
            settled := true
            reject(makeError(`Error initializing stdin read: ${errorMessage}`))
          }
        }
      }
    }
  })
}
