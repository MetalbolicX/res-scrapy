module Process = {
  @val @scope("process") external exit: int => unit = "exit"
  @val @scope("process") external argv: array<string> = "argv"

  type stdInput = {
    isTTY?: bool,
  }

  @val @scope("process") external stdin: stdInput = "stdin"
  @send external onData: (stdInput, @as("data") _, string => unit) => unit = "on"
  @send external onEnd: (stdInput, @as("end") _, unit => unit) => unit = "on"
  @send external onError: (stdInput, @as("error") _, JsExn.t => unit) => unit = "on"
  @send external resume: stdInput => unit = "resume"
  @send external setEncoding: (stdInput, string) => unit = "setEncoding"
}

module Util = {
  @unboxed
  type defaultValue =
    | String(string)
    | Bool(bool)

  type flafConfig = {
    @as("type") type_: string,
    short?: string,
    default?: defaultValue,
  }

  type cliValues = {
    help?: bool,
    selector?: string,
    mode?: string,
    text?: bool,
    schema?: string,
    schemaPath?: string,
  }

  type parseResults = {
    values: cliValues,
    positionals: array<string>,
  }

  type parseConfig = {
    args: array<string>,
    options: dict<flafConfig>,
    strict?: bool,
    allowPositionals?: bool,
    tokens?: bool,
  }

  @module("node:util") external parseArgs: parseConfig => parseResults = "parseArgs"
}

@val @scope("JSON") external jsonStringify: 'a => string = "stringify"
