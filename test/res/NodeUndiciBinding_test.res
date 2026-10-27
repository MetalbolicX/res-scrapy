open Test
open Assertions
open NodeUndiciBinding

// Literal records only: these tests never inspect or change the runner's env.
let proxy = "http://proxy.invalid:8080"
let cases: array<(string, proxyEnv, bool)> = [
  ("lowercase http_proxy", {http_proxy: proxy}, true),
  ("lowercase https_proxy", {https_proxy: proxy}, true),
  ("lowercase all_proxy", {all_proxy: proxy}, true),
  ("uppercase HTTP_PROXY", {httpProxy: proxy}, true),
  ("uppercase HTTPS_PROXY", {httpsProxy: proxy}, true),
  ("uppercase ALL_PROXY", {allProxy: proxy}, true),
  ("all absent", {}, false),
  (
    "all empty",
    {httpProxy: "", http_proxy: "", httpsProxy: "", https_proxy: "", allProxy: "", all_proxy: ""},
    false,
  ),
  ("only NO_PROXY", {noProxy: "example.invalid"}, false),
  ("only no_proxy", {no_proxy: "example.invalid"}, false),
  ("both bypass variables", {noProxy: "*", no_proxy: "*"}, false),
  ("mixed case present", {httpProxy: proxy, https_proxy: proxy, no_proxy: "*"}, true),
  ("empty uppercase does not hide lowercase", {httpProxy: "", http_proxy: proxy}, true),
]

cases->Array.forEach(((name, env, expected)) => {
  test(`proxy activation: ${name}`, () => isTruthy(hasProxyEnv(env) == expected))
})
