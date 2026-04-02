module Process = {
  @val @scope("process") external exit: int => unit = "exit"
  @val @scope("process") external argv: array<string> = "argv"

  type stdInput = {
    isTTY: option<bool>,
  }

  @val @scope("process") external stdin: stdInput = "stdin"
  @send external onData: (stdInput, @as("data") _, string => unit) => unit = "on"
  @send external onEnd: (stdInput, @as("end") _, unit => unit) => unit = "on"
  @send external onError: (stdInput, @as("error") _, JsExn.t => unit) => unit = "on"
  @send external resume: stdInput => unit = "resume"
  @send external setEncoding: (stdInput, string) => unit = "setEncoding"
}

module Util = {
  type cliArgs = {
    help: Nullable.t<bool>,
    selector: Nullable.t<string>,
    mode: Nullable.t<string>,
    text: Nullable.t<string>,
    schema: Nullable.t<string>,
    schemaPath: Nullable.t<string>,
  }

  @module("util")
  external parseArgs: {
    "args": array<string>,
    "allowPositionals": bool,
    "strict": bool,
    "options": {..},
  } => {"values": cliArgs} = "parseArgs"
}
