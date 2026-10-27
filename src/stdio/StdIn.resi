type stdInError =
  | NoInput(string)
  | EmptyContent(string)
  | ReadError(string)

let maxStdinBytes: int
let hasStdinData: unit => bool
let readFromStream: (
  ~stream: NodeProcess.stdInput,
  ~maxBytes: int=?,
  ~timeoutMs: int=?,
  unit,
) => promise<Result.t<string, stdInError>>
let readFromStdin: unit => promise<Result.t<string, stdInError>>
