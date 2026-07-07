open Test
open Assertions

type event =
  | Out(string)
  | Err(string)
  | Warn(string)
  | Exit(int)

type fileWrite = {path: string, content: string}

let makeState = () => {
  let events: ref<array<event>> = ref([])
  let push = e => events := Array.concat(events.contents, [e])
  let getEvents = () => events.contents
  (push, getEvents)
}

/* Records every (sync and async) file write invoked through the `fs`
   dependency. Defaults to no-op mocks for both, but tests that exercise
   file output can substitute the recording implementations returned
   by this helper. */
let makeFileMock = () => {
  let writes: ref<array<fileWrite>> = ref([])
  let record = (path, content) => writes := Array.concat(writes.contents, [{path, content}])
  let writeFileSync = (path, content) =>
    if content == "]" {
      failWith("endJsonArraySync must not use writeFileSync; it would overwrite the output file")
    } else {
      record(path, content)
    }
  let appendFileSync = (path, content) => record(path, content)
  let appendFile = (path, content) => {
    record(path, content)
    Promise.resolve()
  }
  let getWrites = () => writes.contents
  (writeFileSync, appendFileSync, appendFile, getWrites)
}

let makeUrlRunnerDeps = (
  ~fetchResults: array<Fetcher.fetchResult>,
  ~parseTemplateResult: result<array<string>, TemplateParser.parseError>,
  ~appendFile: (string, string) => promise<unit>=(_, _) => Promise.resolve(),
  ~appendFileSync: (string, string) => unit=(_, _) => (),
  ~writeFileSync: (string, string) => unit=(_, _) => (),
): AppContext.dependencies => {
  cli: {
    parseCli: () => {
      selector: ".item",
      mode: false,
      extract: "text",
    },
    validateArgs: _ => Ok({
      selector: ".item",
      extract: ParseCli.Text,
      mode: ParseCli.Multiple,
      outputFormat: ParseCli.Ndjson,
      warnings: [],
      concurrency: 5,
      timeoutSeconds: 30,
      retryCount: 3,
      delayMs: 0,
      requestHeaders: [],
    }),
    readStdin: () => Promise.resolve(Ok("")),
    getCliVersion: () => "test",
  },
  fs: {
    writeFile: (_, _) => Promise.resolve(),
    appendFile,
    writeFileSync,
    appendFileSync,
  },
  serialize: {
    stringifyJson: NodeJsBinding.jsonStringify,
    stringifyTableRows: NodeJsBinding.jsonStringify,
    stringifyStrings: NodeJsBinding.jsonStringify,
  },
  doc: {
    documentOps: NodeHtmlDocument.operations,
    extractTable: (_, _) => Ok([]),
    parseTemplate: _ => parseTemplateResult,
  },
  schema: {
    loadSchema: (~isInline as _, _) => Error(FileReadError("unused")),
    applySchema: (_, _) => Error(ExtractionError("unused")),
  },
  fetch: {
    fetchAll: (_, _) => Promise.resolve(fetchResults),
  },
  perf: {
    performanceNow: () => 0.0,
  },
}

let mkUrlRunnerCtx = (~deps: AppContext.dependencies, ~push): AppContext.appContext => {
  deps,
  io: {
    out: msg => push(Out(msg)),
    err: msg => push(Err(msg)),
    warn: msg => push(Warn(msg)),
    exit: code => push(Exit(code)),
  },
}

let exitCodeOf = (events: array<event>): option<int> => {
  events
  ->Array.filter(e =>
    switch e {
    | Exit(_) => true
    | _ => false
    }
  )
  ->Array.get(0)
  ->Option.map(e =>
    switch e {
    | Exit(code) => code
    | _ => 0
    }
  )
}

let outMessagesOf = (events: array<event>): array<string> =>
  events->Array.filterMap(e =>
    switch e {
    | Out(msg) => Some(msg)
    | _ => None
    }
  )

let outCountOf = (events: array<event>): int => outMessagesOf(events)->Array.length

testAsync("runUrlMode exits 0 when all URLs succeed", done_ => {
  let (push, getEvents) = makeState()
  let fetchResults: array<Fetcher.fetchResult> = [
    {
      url: "http://example.com/1",
      result: Ok("<div class=\"item\">A</div><div class=\"item\">B</div>"),
    },
    {
      url: "http://example.com/2",
      result: Ok("<div class=\"item\">C</div><div class=\"item\">D</div>"),
    },
  ]
  let deps = makeUrlRunnerDeps(
    ~fetchResults,
    ~parseTemplateResult=Ok(["http://example.com/1", "http://example.com/2"]),
  )
  let ctx = mkUrlRunnerCtx(~deps, ~push)
  let options: ParseCli.parseOptions = {
    selector: ".item",
    extract: ParseCli.Text,
    mode: ParseCli.Multiple,
    outputFormat: ParseCli.Ndjson,
    warnings: [],
    concurrency: 5,
    timeoutSeconds: 30,
    retryCount: 3,
    delayMs: 0,
    requestHeaders: [],
  }

  UrlRunner.runUrlMode(ctx, "http://example.com/{1..2}", options)
  ->Promise.then(_ => {
    let events = getEvents()
    isOptionEqualTo(None, exitCodeOf(events), ~eq=(a, b) => a == b)
    done_(~planned=1, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("runUrlMode should not throw")
    done_(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("runUrlMode exits 1 when all URLs fail", done_ => {
  let (push, getEvents) = makeState()
  let fetchResults: array<Fetcher.fetchResult> = [
    {url: "http://example.com/1", result: Error(Fetcher.NetworkError("ECONNREFUSED"))},
    {url: "http://example.com/2", result: Error(Fetcher.HttpError(500, "Internal Server Error"))},
  ]
  let deps = makeUrlRunnerDeps(
    ~fetchResults,
    ~parseTemplateResult=Ok(["http://example.com/1", "http://example.com/2"]),
  )
  let ctx = mkUrlRunnerCtx(~deps, ~push)
  let options: ParseCli.parseOptions = {
    selector: ".item",
    extract: ParseCli.Text,
    mode: ParseCli.Multiple,
    outputFormat: ParseCli.Ndjson,
    warnings: [],
    concurrency: 5,
    timeoutSeconds: 30,
    retryCount: 3,
    delayMs: 0,
    requestHeaders: [],
  }

  UrlRunner.runUrlMode(ctx, "http://example.com/{1..2}", options)
  ->Promise.then(_ => {
    let events = getEvents()
    isOptionEqualTo(Some(1), exitCodeOf(events), ~eq=(a, b) => a == b)
    done_(~planned=1, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("runUrlMode should not throw")
    done_(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("runUrlMode exits 0 with partial success", done_ => {
  let (push, getEvents) = makeState()
  let fetchResults: array<Fetcher.fetchResult> = [
    {
      url: "http://example.com/1",
      result: Ok("<div class=\"item\">A</div><div class=\"item\">B</div>"),
    },
    {url: "http://example.com/2", result: Error(Fetcher.HttpError(404, "Not Found"))},
  ]
  let deps = makeUrlRunnerDeps(
    ~fetchResults,
    ~parseTemplateResult=Ok(["http://example.com/1", "http://example.com/2"]),
  )
  let ctx = mkUrlRunnerCtx(~deps, ~push)
  let options: ParseCli.parseOptions = {
    selector: ".item",
    extract: ParseCli.Text,
    mode: ParseCli.Multiple,
    outputFormat: ParseCli.Ndjson,
    warnings: [],
    concurrency: 5,
    timeoutSeconds: 30,
    retryCount: 3,
    delayMs: 0,
    requestHeaders: [],
  }

  UrlRunner.runUrlMode(ctx, "http://example.com/{1..2}", options)
  ->Promise.then(_ => {
    let events = getEvents()
    isOptionEqualTo(None, exitCodeOf(events), ~eq=(a, b) => a == b)
    done_(~planned=1, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("runUrlMode should not throw")
    done_(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("runUrlMode exits 1 on invalid URL template", done_ => {
  let (push, getEvents) = makeState()
  let deps = makeUrlRunnerDeps(
    ~fetchResults=[],
    ~parseTemplateResult=Error(TemplateParser.InvalidSyntax("unclosed {{")),
  )
  let ctx = mkUrlRunnerCtx(~deps, ~push)
  let options: ParseCli.parseOptions = {
    selector: ".item",
    extract: ParseCli.Text,
    mode: ParseCli.Multiple,
    outputFormat: ParseCli.Ndjson,
    warnings: [],
    concurrency: 5,
    timeoutSeconds: 30,
    retryCount: 3,
    delayMs: 0,
    requestHeaders: [],
  }

  UrlRunner.runUrlMode(ctx, "http://example.com/{{invalid", options)
  ->Promise.then(_ => {
    let events = getEvents()
    isOptionEqualTo(Some(1), exitCodeOf(events), ~eq=(a, b) => a == b)
    done_(~planned=1, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("runUrlMode should not throw")
    done_(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("runUrlMode exits 1 when template produces no URLs", done_ => {
  let (push, getEvents) = makeState()
  let deps = makeUrlRunnerDeps(~fetchResults=[], ~parseTemplateResult=Ok([]))
  let ctx = mkUrlRunnerCtx(~deps, ~push)
  let options: ParseCli.parseOptions = {
    selector: ".item",
    extract: ParseCli.Text,
    mode: ParseCli.Multiple,
    outputFormat: ParseCli.Ndjson,
    warnings: [],
    concurrency: 5,
    timeoutSeconds: 30,
    retryCount: 3,
    delayMs: 0,
    requestHeaders: [],
  }

  UrlRunner.runUrlMode(ctx, "http://example.com/{3..1}", options)
  ->Promise.then(_ => {
    let events = getEvents()
    isOptionEqualTo(Some(1), exitCodeOf(events), ~eq=(a, b) => a == b)
    done_(~planned=1, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("runUrlMode should not throw")
    done_(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("runUrlMode exits 1 when NDJSON file write fails", done_ => {
  let (push, getEvents) = makeState()
  let fetchResults: array<Fetcher.fetchResult> = [
    {
      url: "http://example.com/1",
      result: Ok("<div class=\"item\">A</div><div class=\"item\">B</div>"),
    },
  ]
  let appendFileMock = (_path, _text) => {
    %raw(`Promise.reject(new Error("Disk full"))`)
  }
  let deps = makeUrlRunnerDeps(
    ~fetchResults,
    ~parseTemplateResult=Ok(["http://example.com/1"]),
    ~appendFile=appendFileMock,
  )
  let ctx = mkUrlRunnerCtx(~deps, ~push)
  let options: ParseCli.parseOptions = {
    selector: ".item",
    extract: ParseCli.Text,
    mode: ParseCli.Multiple,
    output: "out.ndjson",
    outputFormat: ParseCli.Ndjson,
    warnings: [],
    concurrency: 5,
    timeoutSeconds: 30,
    retryCount: 3,
    delayMs: 0,
    requestHeaders: [],
  }

  UrlRunner.runUrlMode(ctx, "http://example.com/{1..1}", options)
  ->Promise.then(_ => {
    let events = getEvents()
    isOptionEqualTo(Some(1), exitCodeOf(events), ~eq=(a, b) => a == b)
    done_(~planned=1, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("runUrlMode streams 3 successful fetches as a JSON array", done_ => {
  let (push, getEvents) = makeState()
  let (writeFileSync, appendFileSync, appendFile, getWrites) = makeFileMock()
  let fetchResults: array<Fetcher.fetchResult> = [
    {
      url: "http://example.com/1",
      result: Ok("<div class=\"item\">A</div><div class=\"item\">B</div>"),
    },
    {
      url: "http://example.com/2",
      result: Ok("<div class=\"item\">C</div>"),
    },
    {
      url: "http://example.com/3",
      result: Ok("<div class=\"item\">D</div><div class=\"item\">E</div>"),
    },
  ]
  let deps = makeUrlRunnerDeps(
    ~fetchResults,
    ~parseTemplateResult=Ok([
      "http://example.com/1",
      "http://example.com/2",
      "http://example.com/3",
    ]),
    ~appendFile,
    ~appendFileSync,
    ~writeFileSync,
  )
  let ctx = mkUrlRunnerCtx(~deps, ~push)
  let options: ParseCli.parseOptions = {
    selector: ".item",
    extract: ParseCli.Text,
    mode: ParseCli.Multiple,
    output: "out.json",
    outputFormat: ParseCli.Json,
    warnings: [],
    concurrency: 5,
    timeoutSeconds: 30,
    retryCount: 3,
    delayMs: 0,
    requestHeaders: [],
  }

  UrlRunner.runUrlMode(ctx, "http://example.com/{1..3}", options)
  ->Promise.then(_ => {
    let events = getEvents()
    // No error exit expected
    isOptionEqualTo(None, exitCodeOf(events), ~eq=(a, b) => a == b)

    let writes = getWrites()
    // First write opens with "[", last write closes with "]"
    let first = writes->Belt.Array.get(0)
    let last = writes->Belt.Array.get(Array.length(writes) - 1)
    isOptionEqualTo(
      Some({path: "out.json", content: "["}),
      first,
      ~eq=(a, b) => a.path == b.path && a.content == b.content,
    )
    isOptionEqualTo(
      Some({path: "out.json", content: "]"}),
      last,
      ~eq=(a, b) => a.path == b.path && a.content == b.content,
    )

    // Concatenating every recorded write yields a valid JSON array with 5
    // rows in source order: A, B, C, D, E.
    let reassembled = writes->Array.map(w => w.content)->Array.join("")
    switch NodeJsBinding.jsonParse(reassembled) {
    | Some(JSON.Array(rows)) => isIntEqualTo(5, Array.length(rows))
    | _ => failWith(`reassembled output is not a JSON array: ${reassembled}`)
    }

    done_(~planned=4, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("runUrlMode should not throw")
    done_(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("runUrlMode writes empty JSON array when all fetches fail", done_ => {
  let (push, getEvents) = makeState()
  let (writeFileSync, appendFileSync, appendFile, getWrites) = makeFileMock()
  let fetchResults: array<Fetcher.fetchResult> = [
    {url: "http://example.com/1", result: Error(Fetcher.NetworkError("ECONNREFUSED"))},
    {url: "http://example.com/2", result: Error(Fetcher.HttpError(500, "Internal Server Error"))},
  ]
  let deps = makeUrlRunnerDeps(
    ~fetchResults,
    ~parseTemplateResult=Ok(["http://example.com/1", "http://example.com/2"]),
    ~appendFile,
    ~appendFileSync,
    ~writeFileSync,
  )
  let ctx = mkUrlRunnerCtx(~deps, ~push)
  let options: ParseCli.parseOptions = {
    selector: ".item",
    extract: ParseCli.Text,
    mode: ParseCli.Multiple,
    output: "empty.json",
    outputFormat: ParseCli.Json,
    warnings: [],
    concurrency: 5,
    timeoutSeconds: 30,
    retryCount: 3,
    delayMs: 0,
    requestHeaders: [],
  }

  UrlRunner.runUrlMode(ctx, "http://example.com/{1..2}", options)
  ->Promise.then(_ => {
    let events = getEvents()
    // All fetches failed → non-zero exit
    isOptionEqualTo(Some(1), exitCodeOf(events), ~eq=(a, b) => a == b)

    // Even with zero rows, the file must contain a valid empty JSON array
    let writes = getWrites()
    isIntEqualTo(2, Array.length(writes))
    switch (Belt.Array.get(writes, 0), Belt.Array.get(writes, 1)) {
    | (Some(first), Some(second)) =>
      isTextEqualTo("[", first.content)
      isTextEqualTo("]", second.content)
      isTextEqualTo("empty.json", first.path)
      isTextEqualTo("empty.json", second.path)
    | _ => failWith("expected exactly two file writes")
    }

    let reassembled = writes->Array.map(w => w.content)->Array.join("")
    switch NodeJsBinding.jsonParse(reassembled) {
    | Some(JSON.Array(rows)) => isIntEqualTo(0, Array.length(rows))
    | _ => failWith("reassembled output is not an empty JSON array")
    }

    done_(~planned=7, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("runUrlMode should not throw")
    done_(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})
