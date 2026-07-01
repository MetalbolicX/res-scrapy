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

let makeUrlRunnerDeps = (
  ~fetchResults: array<Fetcher.fetchResult>,
  ~parseTemplateResult: result<array<string>, TemplateParser.parseError>,
  ~appendFile: ((string, string) => promise<unit>)=(_, _) => Promise.resolve(),
): AppContext.dependencies => {
  cli: {
    parseCli: () => {
      selector: ".item",
      mode: false,
      extract: "text",
    },
    validateArgs: _ =>
      Ok({
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
    appendFile: appendFile,
    writeFileSync: (_, _) => (),
    appendFileSync: (_, _) => (),
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

let mkUrlRunnerCtx = (
  ~deps: AppContext.dependencies,
  ~push,
): AppContext.appContext => {
  deps: deps,
  io: {
    out: msg => push(Out(msg)),
    err: msg => push(Err(msg)),
    warn: msg => push(Warn(msg)),
    exit: code => push(Exit(code)),
  },
}

let exitCodeOf = (events: array<event>): option<int> => {
  events->Array.filter(e =>
    switch e {
    | Exit(_) => true
    | _ => false
    }
  )->Array.get(0)->Option.map(e =>
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
    {url: "http://example.com/1", result: Ok("<div class=\"item\">A</div><div class=\"item\">B</div>")},
    {url: "http://example.com/2", result: Ok("<div class=\"item\">C</div><div class=\"item\">D</div>")},
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
    {url: "http://example.com/1", result: Ok("<div class=\"item\">A</div><div class=\"item\">B</div>")},
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
  let deps = makeUrlRunnerDeps(
    ~fetchResults=[],
    ~parseTemplateResult=Ok([]),
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
    {url: "http://example.com/1", result: Ok("<div class=\"item\">A</div><div class=\"item\">B</div>")},
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
