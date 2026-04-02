type stdInError =
  | NoInput(string)
  | EmptyContent(string)
  | ReadError(string)

let readFromStdin: unit => promise<Result.t<string, stdInError>>
