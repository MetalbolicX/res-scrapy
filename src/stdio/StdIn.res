type stdInError =
  | NoInput(string)
  | EmptyContent(string)
  | ReadError(string)

let hasStdinData: unit => bool = () => {
  open Bindings.Process
  switch stdin.isTTY {
  | Some(true) => false
  | _ => true
  }
}

let readFromStdin: unit => promise<Result.t<string, stdInError>> = () => {
  Promise.make((resolve, _reject) => {
    let data = ref("")
    if !hasStdinData() {
      resolve(Result.Error(NoInput("No HTML input provided via stdin")))
    } else {
      open Bindings.Process

      stdin->setEncoding("utf8")

      stdin->onData(chunk => {
        data := data.contents ++ chunk
      })

      stdin->onEnd(() => {
        let content = data.contents->String.trim
        switch content->String.length {
        | 0 => resolve(Result.Error(EmptyContent("Empty HTML content received from stdin")))
        | _ => resolve(Result.Ok(content))
        }
      })

      stdin->onError(error => {
        let errorMessage = switch error->JsExn.message {
        | Some(msg) => msg
        | None => "Unknown error"
        }

        resolve(Result.Error(ReadError(`Error reading stdin: ${errorMessage}`)))
      })

      stdin->resume
    }
  })
}
