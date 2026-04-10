open Test
open Assertions
open TestHelpers
open CliRunner

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
  let schemaPath = "/tmp/res-scrapy-test-schema.json"
  let schemaContent = `{"fields":{"intro":{"selector":"#intro","type":"text"}}}`
  runCliWithSchemaFile(~schemaPath, ~schemaContent, ~cliArgs=[], ~input=html)
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
