type outputTarget =
  | Stdout
  | File(string)

let exnMessage = exn =>
  switch exn->JsExn.fromException {
  | Some(jsExn) => jsExn->JsExn.message->Option.getOr("Unknown error")
  | None => "Unknown error"
  }

let jsonArrayToNdjson: string => option<string> = %raw(`raw => {
  try {
    const value = JSON.parse(raw);
    if (!Array.isArray(value)) {
      return undefined;
    }
    return value.map(item => JSON.stringify(item)).join("\n");
  } catch {
    return undefined;
  }
}`)

let writeText = (
  ~target: outputTarget,
  ~text: string,
  ~writeFile: (string, string) => unit,
  ~out: string => unit,
): result<unit, AppError.appError> =>
  switch target {
  | Stdout => {
      out(text)
      Ok(())
    }
  | File(path) =>
    try {
      writeFile(path, text)
      Ok(())
    } catch {
    | exn => Error(AppError.WriteError(`Failed to write output file "${path}": ${exnMessage(exn)}`))
    }
  }

let write = (
  ~target: outputTarget,
  ~format: ParseCli.outputFormat,
  ~jsonText: string,
  ~writeFile: (string, string) => unit,
  ~out: string => unit,
): result<unit, AppError.appError> =>
  switch target {
  | Stdout => writeText(~target, ~text=jsonText, ~writeFile, ~out)
  | File(_) =>
    switch format {
    | Json => writeText(~target, ~text=jsonText, ~writeFile, ~out)
    | Ndjson =>
      switch jsonArrayToNdjson(jsonText) {
      | Some(ndjson) => writeText(~target, ~text=ndjson, ~writeFile, ~out)
      | None =>
        Error(
          AppError.WriteError("Cannot write NDJSON output: expected extraction result to be a JSON array"),
        )
      }
    }
  }
