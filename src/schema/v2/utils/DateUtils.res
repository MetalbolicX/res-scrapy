/** Date parsing and formatting utilities for the DateTime extractor.
  *
  * JS-heavy parsing/formatting logic lives in the `./date` folder to keep this
  * module typed and easier to maintain from ReScript.
  */
open FieldTypes

module Iter = NodeJsBinding.Iter

type jsDate

@module("./date/parseDate.mjs")
external tryParseWithFormat: (string, string) => option<jsDate> = "default"

@module("./date/formatDate.mjs")
external formatDateInternal: (jsDate, string, string) => string = "default"

/** Try each format in order; return the first successful parse.
  * Defaults to ["ISO"] when the array is empty.
  */
let parseDate: (string, array<string>) => option<jsDate> = (str, formats) => {
  let fmts = if Array.length(formats) === 0 {
    ["ISO"]
  } else {
    formats
  }
  fmts->Iter.values->Iter.reduce((acc, fmt) => {
    switch acc {
    | Some(_) => acc
    | None => tryParseWithFormat(str, fmt)
    }
  }, None)
}

/** Format a `jsDate` according to the `dateOutput` variant. */
let formatDate: (jsDate, dateOutput, option<string>) => string = (date, output, timezone) => {
  let tz = Option.getOr(timezone, "UTC")
  let spec = switch output {
  | Iso8601 => "iso8601"
  | Epoch => "epoch"
  | EpochMillis => "epochMillis"
  | Custom(fmt) => fmt
  }
  formatDateInternal(date, spec, tz)
}
