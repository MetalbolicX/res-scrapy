type outputTarget =
  | Stdout
  | File(string)

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

/**
  * Computes the actual text payload to write based on the target and format.
  * Shared between sync and async write paths so both apply identical routing:
  * - Stdout always emits raw JSON regardless of the requested format.
  * - File target emits raw JSON when format is Json, or NDJSON-converted
  *   lines when format is Ndjson.
  * Centralising this eliminates the structural duplication that previously
  * existed between `write` and `writeAsync`.
  */
let computeOutputText = (
  ~target: outputTarget,
  ~jsonText: string,
  ~format: ParseCli.outputFormat,
): result<string, AppError.appError> =>
  switch target {
  | Stdout => Ok(jsonText)
  | File(_) =>
    switch format {
    | ParseCli.Json => Ok(jsonText)
    | ParseCli.Ndjson =>
      switch jsonArrayToNdjson(jsonText) {
      | Some(ndjson) => Ok(ndjson)
      | None =>
        Error(
          AppError.WriteError("Cannot write NDJSON output: expected extraction result to be a JSON array"),
        )
      }
    }
  }

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
    | exn => Error(AppError.WriteError("Failed to write output file \"" ++ path ++ "\": " ++ ExnUtils.message(exn)))
    }
  }

let write = (
  ~target: outputTarget,
  ~format: ParseCli.outputFormat,
  ~jsonText: string,
  ~writeFile: (string, string) => unit,
  ~out: string => unit,
): result<unit, AppError.appError> =>
  switch computeOutputText(~target, ~jsonText, ~format) {
  | Error(e) => Error(e)
  | Ok(text) => writeText(~target, ~text, ~writeFile, ~out)
  }

let writeTextAsync = (
  ~target: outputTarget,
  ~text: string,
  ~writeFile: (string, string) => promise<unit>,
  ~out: string => unit,
): promise<result<unit, AppError.appError>> => {
  switch target {
  | Stdout => {
      out(text)
      Promise.resolve(Ok(()))
    }
  | File(path) =>
    writeFile(path, text)
    ->Promise.then(_ => Promise.resolve(Ok(())))
    ->Promise.catch(exn => Promise.resolve(Error(AppError.WriteError("Failed to write output file \"" ++ path ++ "\": " ++ ExnUtils.message(exn)))))
  }
}

let writeAsync = (
  ~target: outputTarget,
  ~format: ParseCli.outputFormat,
  ~jsonText: string,
  ~writeFile: (string, string) => promise<unit>,
  ~out: string => unit,
): promise<result<unit, AppError.appError>> =>
  switch computeOutputText(~target, ~jsonText, ~format) {
  | Error(e) => Promise.resolve(Error(e))
  | Ok(text) => writeTextAsync(~target, ~text, ~writeFile, ~out)
  }

let outputTargetFromOptions = (options: ParseCli.parseOptions): outputTarget =>
  switch options.output {
  | Some(path) => File(path)
  | None => Stdout
  }

let writeOutput = (
  ctx: AppContext.appContext,
  options: ParseCli.parseOptions,
  jsonText: string,
): unit => {
  switch write(
    ~target=outputTargetFromOptions(options),
    ~format=options.outputFormat,
    ~jsonText,
    ~writeFile=ctx.deps.fs.writeFileSync,
    ~out=ctx.io.out,
  ) {
  | Ok(()) => ()
  | Error(err) => {
 ctx.io.err(AppError.toMessage(err))
      ctx.io.exit(1)
    }
  }
}
