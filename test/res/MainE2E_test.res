open Test
open Assertions
open TestHelpers
open CliRunner

testAsync("count constraint CLI rejects before extraction", planned => {
  runCli(
    ~args=["--schema", `{"fields":{"n":{"selector":"i","type":"count","countOptions":{"min":1}}}}`],
    ~input="<i>A</i>",
  )
  ->Promise.then(result => {
    isIntEqualTo(1, result.exitCode)
    isTextEqualTo("", result.stdout)
    isTextEqualTo(
      "Invalid field type \"count option min is accepted but not implemented; this build rejects it instead of silently ignoring it\" for field \"n\"\n",
      result.stderr,
    )
    planned(~planned=3, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

[
  (
    "negative list limit",
    `{"config":{"rowSelector":"ul"},"fields":{"x":{"selector":"li","type":"list","listOptions":{"limit":-1}}}}`,
    "Invalid field type \"listOptions.limit must be a non-negative integer, got -1\" for field \"x\"\n",
  ),
  (
    "string list limit",
    `{"config":{"rowSelector":"ul"},"fields":{"x":{"selector":"li","type":"list","listOptions":{"limit":"2"}}}}`,
    "Invalid field type \"listOptions.limit must be a non-negative integer, got \"2\"\" for field \"x\"\n",
  ),
  (
    "numeric config rowSelector",
    `{"config":{"rowSelector":5},"fields":{"x":{"selector":"li"}}}`,
    "config.rowSelector must be a string, got number\n",
  ),
  (
    "numeric table rowSelector",
    `{"fields":{"t":{"selector":"table","type":"table","tableOptions":{"rowSelector":5,"columns":[{"name":"a","selector":"td"}]}}}}`,
    "Invalid field type \"tableOptions.rowSelector must be a string, got number\" for field \"t\"\n",
  ),
]->Array.forEach(((name, schema, expectedStderr)) => {
  testAsync(`schema type CLI rejects ${name} before extraction`, planned => {
    runCli(~args=["--schema", schema], ~input="<ul><li>a</li><li>b</li><li>c</li></ul>")
    ->Promise.then(
      result => {
        isIntEqualTo(1, result.exitCode)
        isTextEqualTo("", result.stdout)
        isTextEqualTo(expectedStderr, result.stderr)
        planned(~planned=3, ())
        Promise.resolve()
      },
    )
    ->Promise.catch(
      _ => {
        failWith("CLI execution failed")
        planned(~planned=0, ())
        Promise.resolve()
      },
    )
    ->ignore
  })
})

["all", "join"]->Array.forEach(mode => {
  testAsync(`guide attribute CLI ${mode} returns joined string`, planned => {
    runCli(
      ~args=[
        "--schema",
        `{"fields":{"image":{"selector":"img","type":"attribute","attributes":["data-src","src"],"attrMode":"${mode}","attributeOptions":{"joinSep":"|"}}}}`,
      ],
      ~input=`<img data-src="lazy.jpg" src="fallback.jpg">`,
    )
    ->Promise.then(
      result => {
        isIntEqualTo(0, result.exitCode)
        isTextEqualTo("[{\"image\":\"lazy.jpg|fallback.jpg\"}]\n", result.stdout)
        isTextEqualTo("", result.stderr)
        planned(~planned=3, ())
        Promise.resolve()
      },
    )
    ->Promise.catch(
      _ => {
        failWith("CLI execution failed")
        planned(~planned=0, ())
        Promise.resolve()
      },
    )
    ->ignore
  })
})

[
  ("maximum", "<i>I</i><s>A</s><s>B</s>", "[{\"i\":\"I\",\"s\":\"A\"},{\"i\":null,\"s\":\"B\"}]\n"),
  ("equal-length control", "<i>I</i><s>A</s>", "[{\"i\":\"I\",\"s\":\"A\"}]\n"),
]->Array.forEach(((name, input, expected)) => {
  testAsync(`zip CLI ${name}`, planned => {
    runCli(~args=["--schema", `{"fields":{"i":{"selector":"i"},"s":{"selector":"s"}}}`], ~input)
    ->Promise.then(
      result => {
        isIntEqualTo(0, result.exitCode)
        isTextEqualTo(expected, result.stdout)
        isTextEqualTo("", result.stderr)
        planned(~planned=3, ())
        Promise.resolve()
      },
    )
    ->Promise.catch(
      _ => {
        failWith("CLI execution failed")
        planned(~planned=0, ())
        Promise.resolve()
      },
    )
    ->ignore
  })
})

testAsync("table CLI: null tableOptions.rowSelector matches omitted rowSelector", planned => {
  let columns = `"columns":[{"name":"A","selector":"td:nth-child(1)","type":"text"},{"name":"B","selector":"td:nth-child(2)","type":"text"}]`
  // `tbody` starts with a pure header row so both variants must skip it.
  let input = "<table><tbody><tr><th>A</th><th>B</th></tr><tr><td>1</td><td>2</td></tr></tbody></table>"
  let run = async rowSelectorOption =>
    await runCli(
      ~args=[
        "--schema",
        `{"fields":{"t":{"selector":"table","type":"table","tableOptions":{${rowSelectorOption}${columns}}}}}`,
      ],
      ~input,
    )
  let runAssertions = async () => {
    let nullResult = await run(`"rowSelector":null,`)
    let omittedResult = await run("")
    isIntEqualTo(0, nullResult.exitCode)
    isIntEqualTo(0, omittedResult.exitCode)
    isTextEqualTo("[{\"t\":[{\"A\":\"1\",\"B\":\"2\"}]}]\n", nullResult.stdout)
    isTextEqualTo(omittedResult.stdout, nullResult.stdout)
    isTextEqualTo("", nullResult.stderr)
    isTextEqualTo("", omittedResult.stderr)
    planned(~planned=6, ())
  }
  runAssertions()
  ->Promise.catch(exn => {
    failWithExn("table CLI execution failed", exn)
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

/** Builds `<ul>` with `count` × `<li class="item">item number i</li>` so the
    buffered-stdout E2E writes a large known-length payload (> 64 KB, more
    than the kernel pipe absorbs while the reader is paused). */
let itemHtml = (count: int): string => {
  let items = Belt.Array.mapWithIndex(Belt.Array.make(count, 0), (i, _) =>
    `<li class="item">item number ${i->Int.toString}</li>`
  )
  ["<ul>"]->Array.concat(items)->Array.concat(["</ul>"])->Array.join("")
}

// Production passes NodeProcess.exitAfterFlush to the runtime handlers: on
// SIGTERM with stdout paused and unread (188,892 buffered bytes for 10k rows)
// the pre-exitAfterFlush build delivered 0 bytes and still ran its exit; the
// current build must deliver every byte before terminating.
testAsync(
  "SIGTERM with paused stdout flushes buffered output before exit",
  ~timeout=20_000,
  planned => {
    runCliPausedStdoutAndSignal(
      ~args=["--selector", ".item", "--mode", "--extract", "text"],
      ~signal="SIGTERM",
      ~input=itemHtml(10_000),
      ~timeoutMs=15_000,
    )
    ->Promise.then(result => {
      isIntEqualTo(143, result.exitCode)
      isTextEqualTo("Terminated (SIGTERM)\n", result.stderr)
      // 10k rows: 10000×(14 + digits) + 9999 commas + 2 brackets + 1 newline
      // does not escape, and the input is pure ASCII, chars = bytes.
      isIntEqualTo(188892, String.length(result.stdout))
      isTextEqualTo(
        "item number 9999",
        Array.last(result.stdout->TestHelpers.stringArrayFromJsonString)->Option.getOr(""),
      )
      planned(~planned=4, ())
      Promise.resolve()
    })
    ->Promise.catch(exn => {
      failWithExn("SIGTERM paused-stdout CLI execution failed", exn)
      planned(~planned=0, ())
      Promise.resolve()
    })
    ->ignore
  },
)

["$.offers.price", "offers.price"]->Array.forEach(path => {
  testAsync(`guide JSON CLI path: ${path}`, planned => {
    let schema = `{"fields":{"ld":{"selector":"script[type='application/ld+json']","type":"json","jsonOptions":{"path":"${path}"}}}}`
    runCli(
      ~args=["--schema", schema],
      ~input=`<script type="application/ld+json">{"offers":{"price":42}}</script>`,
    )
    ->Promise.then(
      result => {
        isIntEqualTo(0, result.exitCode)
        isTextEqualTo("[{\"ld\":42}]\n", result.stdout)
        isTextEqualTo("", result.stderr)
        planned(~planned=3, ())
        Promise.resolve()
      },
    )
    ->Promise.catch(
      _ => {
        failWith("CLI execution failed")
        planned(~planned=0, ())
        Promise.resolve()
      },
    )
    ->ignore
  })
})

[
  (
    "pure tbody header",
    "<table><tbody><tr><th>A</th><th>B</th></tr><tr><td>1</td><td>2</td></tr></tbody></table>",
    "[{\"A\":\"1\",\"B\":\"2\"}]\n",
  ),
  (
    "thead preservation",
    "<table><thead><tr><th>A</th></tr></thead><tbody><tr><td>1</td></tr></tbody></table>",
    "[{\"A\":\"1\"}]\n",
  ),
]->Array.forEach(((name, input, expected)) => {
  testAsync(`table CLI: ${name}`, planned => {
    runCli(~args=["-t"], ~input)
    ->Promise.then(
      result => {
        isIntEqualTo(0, result.exitCode)
        isTextEqualTo(expected, result.stdout)
        isTextEqualTo("", result.stderr)
        planned(~planned=3, ())
        Promise.resolve()
      },
    )
    ->Promise.catch(
      _ => {
        failWith("CLI execution failed")
        planned(~planned=0, ())
        Promise.resolve()
      },
    )
    ->ignore
  })
})

[
  ("SIGINT", 130, "Interrupted (SIGINT)"),
  ("SIGTERM", 143, "Terminated (SIGTERM)"),
]->Array.forEach(((signal, expectedCode, message)) => {
  testAsync(`runtime handler terminates on ${signal}`, ~timeout=15_000, planned => {
    runCliAndSignal(~args=["-s", "p"], ~signal, ~afterMs=500)
    ->Promise.then(
      result => {
        isIntEqualTo(expectedCode, result.exitCode)
        isTextEqualTo("", result.stdout)
        isTextEqualTo(message ++ "\n", result.stderr)
        planned(~planned=3, ())
        Promise.resolve()
      },
    )
    ->Promise.catch(
      _ => {
        failWith("signal CLI execution failed")
        planned(~planned=0, ())
        Promise.resolve()
      },
    )
    ->ignore
  })
})

[
  ("no fetch flags", ["-s", "p"], ""),
  (
    "explicit timeout",
    ["-s", "p", "--timeout", "5"],
    "Warning: --timeout is ignored in stdin mode (no --url provided).\n",
  ),
  (
    "explicit default retry",
    ["-s", "p", "--retry", "3"],
    "Warning: --retry is ignored in stdin mode (no --url provided).\n",
  ),
  (
    "explicit default delay",
    ["-s", "p", "--delay", "0"],
    "Warning: --delay is ignored in stdin mode (no --url provided).\n",
  ),
]->Array.forEach(((name, args, expectedStderr)) => {
  testAsync(`stdin fetch warning: ${name}`, planned => {
    runCli(~args, ~input="<p>x</p>")
    ->Promise.then(
      result => {
        isIntEqualTo(0, result.exitCode)
        isTextEqualTo("[\"<p>x</p>\"]\n", result.stdout)
        isTextEqualTo(expectedStderr, result.stderr)
        planned(~planned=3, ())
        Promise.resolve()
      },
    )
    ->Promise.catch(
      _ => {
        failWith("CLI execution failed")
        planned(~planned=0, ())
        Promise.resolve()
      },
    )
    ->ignore
  })
})

let tempOutPath: string => string = %raw(`name => {
  const suffix = Math.random().toString(36).slice(2);
  return '/tmp/res-scrapy-' + process.pid + '-' + Date.now() + '-' + suffix + '-' + name;
}`)

let html = `<!DOCTYPE html>
<html>
<head><title>Test</title></head>
<body>
<div id="intro">Hello World</div>
<div class="item">Item 1</div>
<div class="item">Item 2</div>
<div class="item">Item 3</div>
<a href="https://example.com" title="Link Title">Example</a>
<p class="desc">A paragraph</p>
<table>
  <thead><tr><th>Name</th><th>Age</th></tr></thead>
  <tbody>
    <tr><td>Alice</td><td>30</td></tr>
    <tr><td>Bob</td><td>25</td></tr>
  </tbody>
</table>
</body>
</html>`

let tableHtml = `<!DOCTYPE html>
<html>
<body>
<table class="users">
  <thead><tr><th>Name</th><th>Email</th></tr></thead>
  <tbody>
    <tr><td>Carol</td><td>carol@example.com</td></tr>
    <tr><td>Dave</td><td>dave@example.com</td></tr>
  </tbody>
</table>
</body>
</html>`

let unicodeHtml = `<!DOCTYPE html>
<html>
<body>
  <h1 class="title">Café ☕ 日本語 مرحبا</h1>
</body>
</html>`

let malformedHtml = "<div class='item'>A<div><span class='item'>B"

testAsync("simple extraction: single element", planned => {
  runCli(~args=["--selector", "#intro", "--extract", "text"], ~input=html)
  ->Promise.then(result => {
    let arr: array<string> = result.stdout->TestHelpers.stringArrayFromJsonString
    isTextEqualTo("Hello World", arr->Array.get(0)->Option.getOr(""))
    isIntEqualTo(0, result.exitCode)
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("simple extraction: unicode text", planned => {
  runCli(~args=["--selector", ".title", "--extract", "text"], ~input=unicodeHtml)
  ->Promise.then(result => {
    let arr: array<string> = result.stdout->TestHelpers.stringArrayFromJsonString
    isTextEqualTo("Café ☕ 日本語 مرحبا", arr->Array.get(0)->Option.getOr(""))
    isIntEqualTo(0, result.exitCode)
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("simple extraction: malformed html does not crash", planned => {
  runCli(~args=["--selector", ".item", "--mode", "--extract", "text"], ~input=malformedHtml)
  ->Promise.then(result => {
    let arr: array<string> = result.stdout->TestHelpers.stringArrayFromJsonString
    isIntEqualTo(1, arr->Array.length)
    stringContains(arr->Array.get(0)->Option.getOr(""), "A")->isTruthy
    isIntEqualTo(0, result.exitCode)
    planned(~planned=3, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("simple extraction: multiple elements", planned => {
  runCli(~args=["--selector", ".item", "--mode"], ~input=html)
  ->Promise.then(result => {
    let arr: array<string> = result.stdout->TestHelpers.stringArrayFromJsonString
    isIntEqualTo(3, arr->Array.length)
    isIntEqualTo(0, result.exitCode)
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("simple extraction: text mode", planned => {
  runCli(~args=["--selector", "p.desc", "--extract", "text"], ~input=html)
  ->Promise.then(result => {
    let arr: array<string> = result.stdout->TestHelpers.stringArrayFromJsonString
    stringContains(arr->Array.get(0)->Option.getOr(""), "paragraph")->isTruthy
    isIntEqualTo(0, result.exitCode)
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("simple extraction: innerHtml mode", planned => {
  runCli(~args=["--selector", "#intro", "--extract", "innerHtml"], ~input=html)
  ->Promise.then(result => {
    let arr: array<string> = result.stdout->TestHelpers.stringArrayFromJsonString
    stringContains(arr->Array.get(0)->Option.getOr(""), "Hello World")->isTruthy
    isIntEqualTo(0, result.exitCode)
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("simple extraction: attr mode", planned => {
  runCli(~args=["--selector", "a", "--extract", "attr:href"], ~input=html)
  ->Promise.then(result => {
    let arr: array<string> = result.stdout->TestHelpers.stringArrayFromJsonString
    isTextEqualTo("https://example.com", arr->Array.get(0)->Option.getOr(""))
    isIntEqualTo(0, result.exitCode)
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("simple extraction: missing selector returns empty array", planned => {
  runCli(~args=["--selector", ".nonexistent"], ~input=html)
  ->Promise.then(result => {
    let arr: array<string> = result.stdout->TestHelpers.stringArrayFromJsonString
    isIntEqualTo(0, arr->Array.length)
    isIntEqualTo(0, result.exitCode)
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("simple extraction: missing attr returns empty string", planned => {
  runCli(~args=["--selector", "div#intro", "--extract", "attr:title"], ~input=html)
  ->Promise.then(result => {
    let arr: array<string> = result.stdout->TestHelpers.stringArrayFromJsonString
    isTextEqualTo("", arr->Array.get(0)->Option.getOr(""))
    isIntEqualTo(0, result.exitCode)
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("table extraction: basic table", planned => {
  runCli(~args=["--table"], ~input=tableHtml)
  ->Promise.then(result => {
    let arr: array<{..}> = result.stdout->TestHelpers.objectArrayFromJsonString
    isIntEqualTo(2, arr->Array.length)
    let firstRow: {..} = arr->Array.get(0)->Option.getOr(TestHelpers.emptyObject)
    isTextEqualTo("Carol", firstRow["Name"])
    isIntEqualTo(0, result.exitCode)
    planned(~planned=3, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("table extraction: custom selector", planned => {
  runCli(~args=["--table", "--selector", "table.users"], ~input=tableHtml)
  ->Promise.then(result => {
    let arr: array<{..}> = result.stdout->TestHelpers.objectArrayFromJsonString
    isIntEqualTo(2, arr->Array.length)
    isIntEqualTo(0, result.exitCode)
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("schema extraction: minimal schema", planned => {
  let schema = "{\"fields\":{\"t\":{\"selector\":\"p\",\"type\":\"text\"}}}"
  runCli(~args=["--schema", schema], ~input=html)
  ->Promise.then(result => {
    isIntEqualTo(0, result.exitCode)
    planned(~planned=1, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("schema extraction: with field extraction", planned => {
  let schema = `{
    "fields": {
      "intro": {
        "selector": "#intro",
        "type": "text"
      }
    }
  }`
  runCli(~args=["--schema", schema], ~input=html)
  ->Promise.then(result => {
    isIntEqualTo(0, result.exitCode)
    let arr: array<{..}> = result.stdout->TestHelpers.objectArrayFromJsonString
    let firstRow = arr->Array.get(0)->Option.getOr(TestHelpers.emptyObject)
    isTextEqualTo("Hello World", firstRow["intro"])
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("error: missing selector with no schema or table", planned => {
  runCli(~args=[], ~input=html)
  ->Promise.then(result => {
    isIntEqualTo(1, result.exitCode)
    stringContains(result.stderr, "selector")->isTruthy
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("error: unknown CLI flag returns friendly parse error", planned => {
  runCli(~args=["--unknownFlag"], ~input=html)
  ->Promise.then(result => {
    isIntEqualTo(1, result.exitCode)
    stringContains(result.stderr, "Invalid CLI arguments")->isTruthy
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("help flag exits with code 0", planned => {
  runCli(~args=["--help"], ~input="")
  ->Promise.then(result => {
    isIntEqualTo(0, result.exitCode)
    stringContains(result.stdout, "Usage: res-scrapy [options]")->isTruthy
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("version flag exits with code 0 and semantic version", planned => {
  runCli(~args=["--version"], ~input="")
  ->Promise.then(result => {
    isIntEqualTo(0, result.exitCode)
    let trimmed = result.stdout->String.trim
    let matchesSemver: bool = %raw(`s => /^\d+\.\d+\.\d+(-[0-9A-Za-z-.]+)?$/.test(s)`)(trimmed)
    isTruthy(matchesSemver)
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("error: empty stdin", planned => {
  runCli(~args=["--selector", "div"], ~input="")
  ->Promise.then(result => {
    isIntEqualTo(1, result.exitCode)
    stringContains(result.stderr, "Empty")->isTruthy
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("error: invalid schema JSON", planned => {
  let schema = `{invalid json}`
  runCli(~args=["--schema", schema], ~input=html)
  ->Promise.then(result => {
    isIntEqualTo(1, result.exitCode)
    stringContains(result.stderr, "JSON")->isTruthy
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("error: missing selector with attr: extract", planned => {
  runCli(~args=["--extract", "attr:href"], ~input=html)
  ->Promise.then(result => {
    isIntEqualTo(1, result.exitCode)
    stringContains(result.stderr, "selector")->isTruthy
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("schemaPath: loads schema from disk file", planned => {
  let schemaContent = `{"fields":{"intro":{"selector":"#intro","type":"text"}}}`
  runCliWithSchemaFile(~schemaContent, ~cliArgs=[], ~input=html)
  ->Promise.then(result => {
    isIntEqualTo(0, result.exitCode)
    let arr: array<{..}> = result.stdout->TestHelpers.objectArrayFromJsonString
    let firstRow = arr->Array.get(0)->Option.getOr(TestHelpers.emptyObject)
    isTextEqualTo("Hello World", firstRow["intro"])
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("output file: writes json when --output is provided", planned => {
  let outPath = tempOutPath("output.json")
  runCli(
    ~args=["--selector", ".item", "--mode", "--extract", "text", "--output", outPath],
    ~input=html,
  )
  ->Promise.then(result => {
    isIntEqualTo(0, result.exitCode)
    isTextEqualTo("", result.stdout)
    let fileContent = NodeFs.readFileSync(outPath)
    let arr: array<string> = fileContent->TestHelpers.stringArrayFromJsonString
    isIntEqualTo(3, arr->Array.length)
    planned(~planned=3, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("output file: writes ndjson when --format ndjson is provided", planned => {
  let outPath = tempOutPath("output.ndjson")
  runCli(
    ~args=[
      "--selector",
      ".item",
      "--mode",
      "--extract",
      "text",
      "--output",
      outPath,
      "--format",
      "ndjson",
    ],
    ~input=html,
  )
  ->Promise.then(result => {
    isIntEqualTo(0, result.exitCode)
    isTextEqualTo("", result.stdout)
    let fileContent = NodeFs.readFileSync(outPath)
    let lines = fileContent->String.trim->String.split("\n")
    isIntEqualTo(3, lines->Array.length)
    let first = lines->Array.get(0)->Option.getOr("")
    isTextEqualTo("\"Item 1\"", first)
    planned(~planned=4, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("output format is ignored on stdout when --output is absent", planned => {
  runCli(
    ~args=["--selector", ".item", "--mode", "--extract", "text", "--format", "ndjson"],
    ~input=html,
  )
  ->Promise.then(result => {
    isIntEqualTo(0, result.exitCode)
    let arr: array<string> = result.stdout->TestHelpers.stringArrayFromJsonString
    isIntEqualTo(3, arr->Array.length)
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("output file: permission denied returns error", planned => {
  let tempDir = tempOutPath("readonly-dir")
  let readOnlyFile = tempOutPath("readonly-file.json")
  let _ = %raw(`(dir, file) => {
    Nodefs.mkdirSync(dir, { recursive: true });
    Nodefs.writeFileSync(file, '[]');
    Nodefs.chmodSync(file, 0o000);
  }`)(tempDir, readOnlyFile)
  let restorePermissions = (path: string): unit => {
    let _ = %raw(`(file) => {
      try {
        Nodefs.chmodSync(file, 0o600);
      } catch {}
    }`)(path)
  }
  let cleanupPath = (path: string): unit => {
    let _ = %raw(`(target) => {
      try {
        Nodefs.rmSync(target, { recursive: true, force: true });
      } catch {}
    }`)(path)
  }
  runCli(
    ~args=["--selector", ".item", "--mode", "--extract", "text", "--output", readOnlyFile],
    ~input=html,
  )
  ->Promise.then(result => {
    restorePermissions(readOnlyFile)
    cleanupPath(readOnlyFile)
    cleanupPath(tempDir)
    isIntEqualTo(1, result.exitCode)
    stringContains(result.stderr, "Failed to write output file")->isTruthy
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    restorePermissions(readOnlyFile)
    cleanupPath(readOnlyFile)
    cleanupPath(tempDir)
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("output file: writing to directory returns error", planned => {
  let dirPath = tempOutPath("output-dir")
  let _ = %raw(`(dir) => {
    Nodefs.mkdirSync(dir, { recursive: true });
  }`)(dirPath)
  runCli(
    ~args=["--selector", ".item", "--mode", "--extract", "text", "--output", dirPath],
    ~input=html,
  )
  ->Promise.then(result => {
    isIntEqualTo(1, result.exitCode)
    stringContains(result.stderr, "Failed to write output file")->isTruthy
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("output file: invalid format returns CLI error", planned => {
  let outPath = tempOutPath("output.data")
  runCli(
    ~args=["--selector", ".item", "--extract", "text", "--output", outPath, "--format", "xml"],
    ~input=html,
  )
  ->Promise.then(result => {
    isIntEqualTo(1, result.exitCode)
    stringContains(result.stderr, "Invalid --format value")->isTruthy
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(_ => {
    failWith("CLI execution failed")
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

// E2E contract: exactly one proxy warning line per run. Which of the two known
// texts is emitted depends on whether undici's agent actually loads; the unit
// tests in NodeUndiciBinding_test.res pin that choice deterministically.
let undiciUnavailableText = "Warning: HTTP_PROXY/http_proxy/HTTPS_PROXY/https_proxy/ALL_PROXY/all_proxy is set but undici is unavailable — proxy will be ignored. Install undici with: npm install undici"
let allProxyOnlyText = "Warning: ALL_PROXY/all_proxy is set but undici's EnvHttpProxyAgent does not route it — requests will connect directly. Set HTTP_PROXY/HTTPS_PROXY instead."

testAsync(
  "ALL_PROXY-only environment prints exactly one warning on stderr",
  ~timeout=15_000,
  planned => {
    HttpTestServer.start([
      ({path: "/", status: 200, location: None, body: "<h1>ok</h1>"}: HttpTestServer.route),
    ])
    ->Promise.then(server => {
      let run = async () => {
        let outcome = try {
          Ok(
            await runCli(
              ~args=[
                "--url",
                `http://127.0.0.1:${server->HttpTestServer.port->Int.toString}/`,
                "--schema",
                `{"fields":{"title":{"selector":"h1","type":"text"}}}`,
              ],
              ~setEnv=[("ALL_PROXY", "http://proxy.invalid:8080")],
              ~unsetEnv=[
                "HTTP_PROXY",
                "http_proxy",
                "HTTPS_PROXY",
                "https_proxy",
                "NO_PROXY",
                "no_proxy",
              ],
            ),
          )
        } catch {
        | _exn => Error()
        }
        await HttpTestServer.close(server)
        switch outcome {
        | Ok(result) =>
          isIntEqualTo(0, result.exitCode)
          isTextEqualTo(`{"title":"ok"}\n`, result.stdout)
          // The run report (with a variable duration) follows on stderr, so pin
          // the complete set of warning lines rather than the whole stream.
          let warnings =
            result.stderr
            ->String.split("\n")
            ->Array.filter(line => line->String.startsWith("Warning:"))
          // (a) exactly one Warning: line — the run report follows on stderr, so
          // pin the set of warning lines rather than the whole stream.
          isIntEqualTo(1, warnings->Array.length)
          // (b)+(c) that single line is one of the two known texts, never both.
          let matching =
            warnings
            ->Array.get(0)
            ->Option.map(
              first =>
                [undiciUnavailableText, allProxyOnlyText]
                ->Array.filter(w => w == first)
                ->Array.length,
            )
            ->Option.getOr(0)
          isIntEqualTo(1, matching)
          planned(~planned=4, ())
        | Error(_) =>
          failWith("ALL_PROXY warning E2E spawn failed")
          planned(~planned=0, ())
        }
      }
      run()->Promise.catch(
        exn => {
          failWithExn("ALL_PROXY warning E2E assertions failed", exn)
          planned(~planned=0, ())
          Promise.resolve()
        },
      )
    })
    ->Promise.catch(exn => {
      failWithExn("Could not start HTTP test server for ALL_PROXY warning E2E", exn)
      planned(~planned=0, ())
      Promise.resolve()
    })
    ->ignore
  },
)
