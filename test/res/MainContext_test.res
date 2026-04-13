open Test
open Assertions

type event =
  | Out(string)
  | Err(string)
  | Warn(string)
  | Exit(int)

let makeState = () => {
  let events: ref<array<event>> = ref([])
  let push = e => events := Array.concat(events.contents, [e])
  let getEvents = () => events.contents
  (push, getEvents)
}

let mkContext = (~deps, ~push) : AppContext.appContext => {
  deps: deps,
  io: {
    out: msg => push(Out(msg)),
    err: msg => push(Err(msg)),
    warn: msg => push(Warn(msg)),
    exit: code => push(Exit(code)),
  },
}

let simpleDeps = (
  ~cliValues,
  ~parseResult,
  ~stdinResult,
  ~extractResult,
  ~schemaLoadResult,
  ~schemaApplyResult,
): AppContext.dependencies => {
  parseCli: () => cliValues,
  validateArgs: _ => parseResult,
  readStdin: () => Promise.resolve(stdinResult),
  documentOps: NodeHtmlDocument.operations,
  extractTable: (_, _) => extractResult,
  loadSchema: (~isInline, source) => {
    let _ = isInline
    let _ = source
    schemaLoadResult
  },
  applySchema: (_, _) => schemaApplyResult,
  stringifyJson: NodeJsBinding.jsonStringify,
  stringifyTableRows: NodeJsBinding.jsonStringify,
  stringifyStrings: NodeJsBinding.jsonStringify,
}

testAsync("mainWithContext writes selector output", done_ => {
  let (push, getEvents) = makeState()
  let parseResult: result<ParseCli.parseOptions, ParseCli.parseError> =
    Ok({selector: ".item", extract: Text, mode: Multiple})
  let deps = simpleDeps(
    ~cliValues={selector: ".item", mode: true, extract: "text"},
    ~parseResult,
    ~stdinResult=Ok("<div class='item'>A</div><div class='item'>B</div>"),
    ~extractResult=Ok([]),
    ~schemaLoadResult=Error(FileReadError("unused")),
    ~schemaApplyResult=Error(ExtractionError("unused")),
  )
  let ctx = mkContext(~deps, ~push)

  Main.mainWithContext(ctx)
  ->Promise.then(_ => {
    let events = getEvents()
    isIntEqualTo(1, Array.length(events))
    switch Array.get(events, 0) {
    | Some(Out(msg)) => isTextEqualTo("[\"A\",\"B\"]", msg)
    | _ => failWith("Expected one Out event")
    }
    done_(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("mainWithContext should resolve")
    done_(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("mainWithContext reports cli parse errors", done_ => {
  let (push, getEvents) = makeState()
  let deps = simpleDeps(
    ~cliValues={selector: "", mode: false, extract: "outerHtml"},
    ~parseResult=Error(MissingSelector("Selector missing")),
    ~stdinResult=Ok("<div></div>"),
    ~extractResult=Ok([]),
    ~schemaLoadResult=Error(FileReadError("unused")),
    ~schemaApplyResult=Error(ExtractionError("unused")),
  )
  let ctx = mkContext(~deps, ~push)

  Main.mainWithContext(ctx)
  ->Promise.then(_ => {
    let events = getEvents()
    isIntEqualTo(2, Array.length(events))
    switch (Array.get(events, 0), Array.get(events, 1)) {
    | (Some(Err(msg)), Some(Exit(code))) => {
        isTextEqualTo("Selector missing", msg)
        isIntEqualTo(1, code)
      }
    | _ => failWith("Expected Err then Exit")
    }
    done_(~planned=3, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("mainWithContext should resolve")
    done_(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})
