open Test
open Assertions
open TestHelpers

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

let throwError: string => 'a = %raw(`msg => {
  throw new Error(msg);
}`)

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
  writeFile: (_, _) => (),
  stringifyJson: NodeJsBinding.jsonStringify,
  stringifyTableRows: NodeJsBinding.jsonStringify,
  stringifyStrings: NodeJsBinding.jsonStringify,
}

testAsync("mainWithContext writes selector output", done_ => {
  let (push, getEvents) = makeState()
  let parseResult: result<ParseCli.parseOptions, ParseCli.parseError> =
    Ok({selector: ".item", extract: Text, mode: Multiple, outputFormat: Json})
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

testAsync("mainWithContext catches parseCli exceptions", done_ => {
  let (push, getEvents) = makeState()
  let deps: AppContext.dependencies = {
    ...simpleDeps(
      ~cliValues={},
      ~parseResult=Ok({selector: ".item", extract: Text, mode: Single, outputFormat: Json}),
      ~stdinResult=Ok("<div class='item'>A</div>"),
      ~extractResult=Ok([]),
      ~schemaLoadResult=Error(FileReadError("unused")),
      ~schemaApplyResult=Error(ExtractionError("unused")),
    ),
    parseCli: () => throwError("bad args"),
  }
  let ctx = mkContext(~deps, ~push)

  Main.mainWithContext(ctx)
  ->Promise.then(_ => {
    let events = getEvents()
    isIntEqualTo(2, Array.length(events))
    switch (Array.get(events, 0), Array.get(events, 1)) {
    | (Some(Err(msg)), Some(Exit(code))) => {
        stringContains(msg, "Invalid CLI arguments")->isTruthy
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

testAsync("mainWithContext catches HTML parse exceptions", done_ => {
  let (push, getEvents) = makeState()
  let throwingOps: Document.operations = {
    ...NodeHtmlDocument.operations,
    parse: _ => throwError("broken html"),
  }
  let deps: AppContext.dependencies = {
    ...simpleDeps(
      ~cliValues={selector: ".item", extract: "text"},
      ~parseResult=Ok({selector: ".item", extract: Text, mode: Single, outputFormat: Json}),
      ~stdinResult=Ok("<div class='item'>A</div>"),
      ~extractResult=Ok([]),
      ~schemaLoadResult=Error(FileReadError("unused")),
      ~schemaApplyResult=Error(ExtractionError("unused")),
    ),
    documentOps: throwingOps,
  }
  let ctx = mkContext(~deps, ~push)

  Main.mainWithContext(ctx)
  ->Promise.then(_ => {
    let events = getEvents()
    isIntEqualTo(2, Array.length(events))
    switch (Array.get(events, 0), Array.get(events, 1)) {
    | (Some(Err(msg)), Some(Exit(code))) => {
        stringContains(msg, "Failed to parse HTML input")->isTruthy
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
