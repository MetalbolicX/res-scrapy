open Test
open Assertions
open TestHelpers
open CliRunner

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

testAsync("simple extraction: single element", (planned) => {
  runCli(~args=["--selector", "#intro", "--extract", "text"], ~input=html)
  ->Promise.then(result => {
    let arr: array<string> = result.stdout->TestHelpers.arrayFromJsonString->Obj.magic
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

testAsync("simple extraction: unicode text", (planned) => {
  runCli(~args=["--selector", ".title", "--extract", "text"], ~input=unicodeHtml)
  ->Promise.then(result => {
    let arr: array<string> = result.stdout->TestHelpers.arrayFromJsonString->Obj.magic
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

testAsync("simple extraction: malformed html does not crash", (planned) => {
  runCli(~args=["--selector", ".item", "--mode", "--extract", "text"], ~input=malformedHtml)
  ->Promise.then(result => {
    let arr: array<string> = result.stdout->TestHelpers.arrayFromJsonString->Obj.magic
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

testAsync("simple extraction: multiple elements", (planned) => {
  runCli(~args=["--selector", ".item", "--mode"], ~input=html)
  ->Promise.then(result => {
    let arr: array<string> = result.stdout->TestHelpers.arrayFromJsonString->Obj.magic
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

testAsync("simple extraction: text mode", (planned) => {
  runCli(~args=["--selector", "p.desc", "--extract", "text"], ~input=html)
  ->Promise.then(result => {
    let arr: array<string> = result.stdout->TestHelpers.arrayFromJsonString->Obj.magic
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

testAsync("simple extraction: innerHtml mode", (planned) => {
  runCli(~args=["--selector", "#intro", "--extract", "innerHtml"], ~input=html)
  ->Promise.then(result => {
    let arr: array<string> = result.stdout->TestHelpers.arrayFromJsonString->Obj.magic
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

testAsync("simple extraction: attr mode", (planned) => {
  runCli(~args=["--selector", "a", "--extract", "attr:href"], ~input=html)
  ->Promise.then(result => {
    let arr: array<string> = result.stdout->TestHelpers.arrayFromJsonString->Obj.magic
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

testAsync("simple extraction: missing selector returns empty array", (planned) => {
  runCli(~args=["--selector", ".nonexistent"], ~input=html)
  ->Promise.then(result => {
    let arr: array<string> = result.stdout->TestHelpers.arrayFromJsonString->Obj.magic
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

testAsync("simple extraction: missing attr returns empty string", (planned) => {
  runCli(~args=["--selector", "div#intro", "--extract", "attr:title"], ~input=html)
  ->Promise.then(result => {
    let arr: array<string> = result.stdout->TestHelpers.arrayFromJsonString->Obj.magic
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

testAsync("table extraction: basic table", (planned) => {
  runCli(~args=["--table"], ~input=tableHtml)
  ->Promise.then(result => {
    let arr: array<{..}> = result.stdout->TestHelpers.arrayFromJsonString->Obj.magic
    isIntEqualTo(2, arr->Array.length)
    let firstRow: {..} = arr->Array.get(0)->Option.getOr(Obj.magic(%raw("({})")))
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

testAsync("table extraction: custom selector", (planned) => {
  runCli(~args=["--table", "--selector", "table.users"], ~input=tableHtml)
  ->Promise.then(result => {
    let arr: array<{..}> = result.stdout->TestHelpers.arrayFromJsonString->Obj.magic
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

testAsync("schema extraction: minimal schema", (planned) => {
  let schema = `{"fields":{}}`
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

testAsync("schema extraction: with field extraction", (planned) => {
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
    let arr: array<{..}> = result.stdout->TestHelpers.arrayFromJsonString->Obj.magic
    let firstRow = arr->Array.get(0)->Option.getOr(Obj.magic(%raw("({})")))
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

testAsync("error: missing selector with no schema or table", (planned) => {
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

testAsync("error: unknown CLI flag returns friendly parse error", (planned) => {
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

testAsync("help flag exits with code 0", (planned) => {
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

testAsync("version flag exits with code 0 and semantic version", (planned) => {
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

testAsync("error: empty stdin", (planned) => {
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

testAsync("error: invalid schema JSON", (planned) => {
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

testAsync("error: missing selector with attr: extract", (planned) => {
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

testAsync("schemaPath: loads schema from disk file", (planned) => {
  let schemaContent = `{"fields":{"intro":{"selector":"#intro","type":"text"}}}`
  runCliWithSchemaFile(~schemaContent, ~cliArgs=[], ~input=html)
  ->Promise.then(result => {
    isIntEqualTo(0, result.exitCode)
    let arr: array<{..}> = result.stdout->TestHelpers.arrayFromJsonString->Obj.magic
    let firstRow = arr->Array.get(0)->Option.getOr(Obj.magic(%raw("({})")))
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
  runCli(~args=["--selector", ".item", "--mode", "--extract", "text", "--output", outPath], ~input=html)
  ->Promise.then(result => {
    isIntEqualTo(0, result.exitCode)
    isTextEqualTo("", result.stdout)
    let fileContent = NodeJsBinding.Fs.readFileSync(outPath)
    let arr: array<string> = fileContent->TestHelpers.arrayFromJsonString->Obj.magic
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
    ~args=["--selector", ".item", "--mode", "--extract", "text", "--output", outPath, "--format", "ndjson"],
    ~input=html,
  )
  ->Promise.then(result => {
    isIntEqualTo(0, result.exitCode)
    isTextEqualTo("", result.stdout)
    let fileContent = NodeJsBinding.Fs.readFileSync(outPath)
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
  runCli(~args=["--selector", ".item", "--mode", "--extract", "text", "--format", "ndjson"], ~input=html)
  ->Promise.then(result => {
    isIntEqualTo(0, result.exitCode)
    let arr: array<string> = result.stdout->TestHelpers.arrayFromJsonString->Obj.magic
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
