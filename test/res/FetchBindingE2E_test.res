open Test
open Assertions
open CliRunner

let tempOutPath: string => string = %raw(`name => '/tmp/res-scrapy-fetch-e2e-' + process.pid + '-' + Date.now() + '-' + name`)
let readTextFile: string => promise<
  string,
> = %raw(`path => import('node:fs').then(fs => fs.readFileSync(path, 'utf8'))`)
let errorText: 'a => string = %raw(`error => String(error)`)
let probe = "same-origin"
let userAgent = "res-scrapy-fetch-binding-e2e/025"
let schemaContent = `{"fields":{"title":{"selector":"h1","type":"text"}}}`
let html = "<!doctype html><html><body><h1>ok</h1></body></html>"
let cliArgs = (url, outputPath) => [
  "--url",
  url,
  "--header",
  `X-Probe: ${probe}`,
  "--userAgent",
  userAgent,
  "--output",
  outputPath,
]

let route = (~path, ~status, ~location: option<string>=None, ~body=""): HttpTestServer.route => {
  path,
  status,
  location,
  body,
}

let assertHeader = (server, path, name, expected) =>
  isTextEqualTo(
    expected,
    HttpTestServer.recordedHeader(server, path, name)->Option.getOr("<missing>"),
  )

let runFetch = (url, outputPath) =>
  runCliWithSchemaFile(~schemaContent, ~cliArgs=cliArgs(url, outputPath))

testAsync("default fetch binding keeps user headers on same-origin redirect", planned => {
  HttpTestServer.start([
    route(~path="/start", ~status=302, ~location=Some("http://127.0.0.1:%PORT%/final")),
    route(~path="/final", ~status=200, ~body=html),
  ])
  ->Promise.then(server => {
    let outputPath = tempOutPath("same-origin.json")
    runFetch(`http://127.0.0.1:${server->HttpTestServer.port->Int.toString}/start`, outputPath)
    ->Promise.then(
      result => {
        isIntEqualTo(0, result.exitCode)
        if result.exitCode != 0 {
          failWith(result.stderr)
        }
        readTextFile(outputPath)->Promise.then(
          content => {
            isTruthy(TestHelpers.stringContains(content, "ok"))
            assertHeader(server, "/final", "user-agent", userAgent)
            assertHeader(server, "/final", "x-probe", probe)
            HttpTestServer.close(server)->Promise.then(
              _ => {
                planned(~planned=4, ())
                Promise.resolve()
              },
            )
          },
        )
      },
    )
    ->Promise.catch(
      _ =>
        HttpTestServer.close(server)->Promise.then(
          _ => {
            failWith("Same-origin fetch E2E failed")
            planned(~planned=0, ())
            Promise.resolve()
          },
        ),
    )
  })
  ->Promise.catch(error => {
    failWith(`Same-origin test failed: ${error->errorText}`)
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync(
  "default fetch binding strips user headers across origins but retains User-Agent",
  planned => {
    HttpTestServer.start([route(~path="/landing", ~status=200, ~body=html)])
    ->Promise.then(serverB =>
      HttpTestServer.start([
        route(
          ~path="/hop",
          ~status=302,
          ~location=Some(`http://127.0.0.1:${serverB->HttpTestServer.port->Int.toString}/landing`),
        ),
      ])
      ->Promise.then(
        serverA => {
          let outputPath = tempOutPath("cross-origin.json")
          runFetch(`http://127.0.0.1:${serverA->HttpTestServer.port->Int.toString}/hop`, outputPath)
          ->Promise.then(
            result => {
              isIntEqualTo(0, result.exitCode)
              if result.exitCode != 0 {
                failWith(result.stderr)
              }
              readTextFile(outputPath)->Promise.then(
                content => {
                  isTruthy(TestHelpers.stringContains(content, "ok"))
                  assertHeader(serverA, "/hop", "x-probe", probe)
                  assertHeader(serverB, "/landing", "user-agent", userAgent)
                  isTruthy(
                    HttpTestServer.recordedHeader(serverB, "/landing", "x-probe")->Option.isNone,
                  )
                  Promise.all([
                    HttpTestServer.close(serverA),
                    HttpTestServer.close(serverB),
                  ])->Promise.then(
                    _ => {
                      planned(~planned=5, ())
                      Promise.resolve()
                    },
                  )
                },
              )
            },
          )
          ->Promise.catch(
            _ =>
              Promise.all([
                HttpTestServer.close(serverA),
                HttpTestServer.close(serverB),
              ])->Promise.then(
                _ => {
                  failWith("Cross-origin fetch E2E failed")
                  planned(~planned=0, ())
                  Promise.resolve()
                },
              ),
          )
        },
      )
      ->Promise.catch(
        _ =>
          HttpTestServer.close(serverB)->Promise.then(
            _ => {
              failWith("Could not start first cross-origin HTTP test server")
              planned(~planned=0, ())
              Promise.resolve()
            },
          ),
      )
    )
    ->Promise.catch(error => {
      failWith(`Cross-origin test failed: ${error->errorText}`)
      planned(~planned=0, ())
      Promise.resolve()
    })
    ->ignore
  },
)
