type stdInError =
  | NoInput(string)
  | EmptyContent(string)
  | ReadError(string)

let hasStdinData: unit => bool
let readFromStdin: unit => promise<Result.t<string, stdInError>>
