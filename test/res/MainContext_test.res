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
  appendFile: (_, _) => (),
  stringifyJson: NodeJsBinding.jsonStringify,
  stringifyTableRows: NodeJsBinding.jsonStringify,
  stringifyStrings: NodeJsBinding.jsonStringify,
  parseTemplate: _ => Error(TemplateParser.InvalidSyntax("not implemented")),
  fetchAll: (_, _) => Promise.resolve([]),
  getCliVersion: () => "test",
  performanceNow: () => 0.0,
}

testAsync("mainWithContext writes selector output", done_ => {
  let (push, getEvents) = makeState()
  let parseResult: result<ParseCli.parseOptions, ParseCli.parseError> =
    Ok({selector: ".item", extract: Text, mode: Multiple, outputFormat: Json, warnings: [], concurrency: 5, timeoutSeconds: 30, retryCount: 3, delayMs: 0, requestHeaders: []})
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

testAsync("mainWithContext reports write error when writeFile throws", done_ => {
  let (push, getEvents) = makeState()
  let parseResult: result<ParseCli.parseOptions, ParseCli.parseError> =
    Ok({selector: ".item", extract: Text, mode: Multiple, output: "/tmp/res-scrapy-write-fail", outputFormat: Json, warnings: [], concurrency: 5, timeoutSeconds: 30, retryCount: 3, delayMs: 0, requestHeaders: []})
  let deps = {
    ...simpleDeps(
      ~cliValues={selector: ".item", mode: true, extract: "text", output: "/tmp/res-scrapy-write-fail", format: "json"},
      ~parseResult,
      ~stdinResult=Ok("<div class='item'>A</div><div class='item'>B</div>"),
      ~extractResult=Ok([]),
      ~schemaLoadResult=Error(FileReadError("unused")),
      ~schemaApplyResult=Error(ExtractionError("unused")),
    ),
    writeFile: (_, _) => throwError("disk full"),
  }
  let ctx = mkContext(~deps, ~push)

  Main.mainWithContext(ctx)
  ->Promise.then(_ => {
    let events = getEvents()
    isIntEqualTo(2, Array.length(events))
    switch (Array.get(events, 0), Array.get(events, 1)) {
    | (Some(Err(msg)), Some(Exit(code))) => {
        stringContains(msg, "Failed to write output file")->isTruthy
        isIntEqualTo(1, code)
      }
    | _ => failWith("Expected Err then Exit for write error")
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

testAsync("mainWithContext reports NDJSON error when result is not an array", done_ => {
  let (push, getEvents) = makeState()
  let parseResult: result<ParseCli.parseOptions, ParseCli.parseError> =
    Ok({selector: ".item", extract: Text, mode: Single, output: "/tmp/res-scrapy-ndjson-fail", outputFormat: Ndjson, warnings: [], concurrency: 5, timeoutSeconds: 30, retryCount: 3, delayMs: 0, requestHeaders: []})
  /* Override stringifyStrings to return a JSON object string so NDJSON conversion fails */
  let depsBase = simpleDeps(
    ~cliValues={selector: ".item", mode: false, extract: "text", output: "/tmp/res-scrapy-ndjson-fail", format: "ndjson"},
    ~parseResult,
    ~stdinResult=Ok("<div class='item'>Only</div>"),
    ~extractResult=Ok([]),
    ~schemaLoadResult=Error(FileReadError("unused")),
    ~schemaApplyResult=Error(ExtractionError("unused")),
  )
  let deps: AppContext.dependencies = {
    ...depsBase,
    stringifyStrings: _ => "{\"notArray\":true}",
  }
  let ctx = mkContext(~deps, ~push)

  Main.mainWithContext(ctx)
  ->Promise.then(_ => {
    let events = getEvents()
    isIntEqualTo(2, Array.length(events))
    switch (Array.get(events, 0), Array.get(events, 1)) {
    | (Some(Err(msg)), Some(Exit(code))) => {
        stringContains(msg, "Cannot write NDJSON output")->isTruthy
        isIntEqualTo(1, code)
      }
    | _ => failWith("Expected Err then Exit for NDJSON conversion error")
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
      ~parseResult=Ok({selector: ".item", extract: Text, mode: Single, outputFormat: Json, warnings: [], concurrency: 5, timeoutSeconds: 30, retryCount: 3, delayMs: 0, requestHeaders: []}),
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

let throwSystemError: (string, string) => 'a = %raw(`(code, msg) => {
  const err = new Error(msg);
  err.code = code;
  throw err;
}`)

testAsync("write error: permission denied (EACCES) exits with code 1", done_ => {
  let (push, getEvents) = makeState()
  let parseResult: result<ParseCli.parseOptions, ParseCli.parseError> =
    Ok({selector: ".item", extract: Text, mode: Multiple, output: "/root/forbidden/output.json", outputFormat: Json, warnings: [], concurrency: 5, timeoutSeconds: 30, retryCount: 3, delayMs: 0, requestHeaders: []})
  let deps = {
    ...simpleDeps(
      ~cliValues={selector: ".item", mode: true, extract: "text", output: "/root/forbidden/output.json", format: "json"},
      ~parseResult,
      ~stdinResult=Ok("<div class='item'>A</div>"),
      ~extractResult=Ok([]),
      ~schemaLoadResult=Error(FileReadError("unused")),
      ~schemaApplyResult=Error(ExtractionError("unused")),
    ),
    writeFile: (_, _) => throwSystemError("EACCES", "EACCES: permission denied, open '/root/forbidden/output.json'"),
  }
  let ctx = mkContext(~deps, ~push)

  Main.mainWithContext(ctx)
  ->Promise.then(_ => {
    let events = getEvents()
    isIntEqualTo(2, Array.length(events))
    switch (Array.get(events, 0), Array.get(events, 1)) {
    | (Some(Err(msg)), Some(Exit(code))) => {
        stringContains(msg, "Failed to write output file")->isTruthy
        stringContains(msg, "/root/forbidden/output.json")->isTruthy
        stringContains(msg, "permission denied")->isTruthy
        isIntEqualTo(1, code)
      }
    | _ => failWith("Expected Err then Exit for permission denied")
    }
    done_(~planned=5, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("mainWithContext should resolve")
    done_(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("write error: non-writable directory path (EISDIR) exits with code 1", done_ => {
  let (push, getEvents) = makeState()
  let parseResult: result<ParseCli.parseOptions, ParseCli.parseError> =
    Ok({selector: ".item", extract: Text, mode: Single, output: "/some/directory/path", outputFormat: Json, warnings: [], concurrency: 5, timeoutSeconds: 30, retryCount: 3, delayMs: 0, requestHeaders: []})
  let deps = {
    ...simpleDeps(
      ~cliValues={selector: ".item", mode: false, extract: "text", output: "/some/directory/path", format: "json"},
      ~parseResult,
      ~stdinResult=Ok("<div class='item'>Only</div>"),
      ~extractResult=Ok([]),
      ~schemaLoadResult=Error(FileReadError("unused")),
      ~schemaApplyResult=Error(ExtractionError("unused")),
    ),
    writeFile: (_, _) => throwSystemError("EISDIR", "EISDIR: illegal operation on a directory, open '/some/directory/path'"),
  }
  let ctx = mkContext(~deps, ~push)

  Main.mainWithContext(ctx)
  ->Promise.then(_ => {
    let events = getEvents()
    isIntEqualTo(2, Array.length(events))
    switch (Array.get(events, 0), Array.get(events, 1)) {
    | (Some(Err(msg)), Some(Exit(code))) => {
        stringContains(msg, "Failed to write output file")->isTruthy
        stringContains(msg, "/some/directory/path")->isTruthy
        stringContains(msg, "illegal operation on a directory")->isTruthy
        isIntEqualTo(1, code)
      }
    | _ => failWith("Expected Err then Exit for directory path error")
    }
    done_(~planned=5, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("mainWithContext should resolve")
    done_(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("write error: permission denied for NDJSON output exits with code 1", done_ => {
  let (push, getEvents) = makeState()
  let parseResult: result<ParseCli.parseOptions, ParseCli.parseError> =
    Ok({selector: ".item", extract: Text, mode: Single, output: "/root/forbidden/output.ndjson", outputFormat: Ndjson, warnings: [], concurrency: 5, timeoutSeconds: 30, retryCount: 3, delayMs: 0, requestHeaders: []})
  let deps = {
    ...simpleDeps(
      ~cliValues={selector: ".item", mode: false, extract: "text", output: "/root/forbidden/output.ndjson", format: "ndjson"},
      ~parseResult,
      ~stdinResult=Ok("<div class='item'>Only</div>"),
      ~extractResult=Ok([]),
      ~schemaLoadResult=Error(FileReadError("unused")),
      ~schemaApplyResult=Error(ExtractionError("unused")),
    ),
    writeFile: (_, _) => throwSystemError("EACCES", "EACCES: permission denied, open '/root/forbidden/output.ndjson'"),
  }
  let ctx = mkContext(~deps, ~push)

  Main.mainWithContext(ctx)
  ->Promise.then(_ => {
    let events = getEvents()
    isIntEqualTo(2, Array.length(events))
    switch (Array.get(events, 0), Array.get(events, 1)) {
    | (Some(Err(msg)), Some(Exit(code))) => {
        stringContains(msg, "Failed to write output file")->isTruthy
        stringContains(msg, "/root/forbidden/output.ndjson")->isTruthy
        stringContains(msg, "permission denied")->isTruthy
        isIntEqualTo(1, code)
      }
    | _ => failWith("Expected Err then Exit for permission denied NDJSON")
    }
    done_(~planned=5, ())
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
      ~parseResult=Ok({selector: ".item", extract: Text, mode: Single, outputFormat: Json, warnings: [], concurrency: 5, timeoutSeconds: 30, retryCount: 3, delayMs: 0, requestHeaders: []}),
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
