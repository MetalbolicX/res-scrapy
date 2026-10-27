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

// PRESERVE: activation is unchanged — ALL_PROXY alone still loads the agent.
test("proxy activation: only ALL_PROXY still activates the agent", () =>
  isTruthy(hasProxyEnv({allProxy: proxy}))
)

// ALL_PROXY/all_proxy alone never routes through undici's EnvHttpProxyAgent.
let allProxyOnlyCases: array<(string, proxyEnv, bool)> = [
  ("only ALL_PROXY", {allProxy: proxy}, true),
  ("only all_proxy", {all_proxy: proxy}, true),
  ("ALL_PROXY with lowercase http_proxy", {allProxy: proxy, http_proxy: proxy}, false),
  ("ALL_PROXY with uppercase HTTP_PROXY", {allProxy: proxy, httpProxy: proxy}, false),
  ("ALL_PROXY with lowercase https_proxy", {allProxy: proxy, https_proxy: proxy}, false),
  ("ALL_PROXY with uppercase HTTPS_PROXY", {allProxy: proxy, httpsProxy: proxy}, false),
  ("ALL_PROXY with empty HTTP_PROXY", {allProxy: proxy, httpProxy: ""}, true),
  ("ALL_PROXY with NO_PROXY", {allProxy: proxy, noProxy: "*"}, true),
  ("nothing set", {}, false),
  ("ALL_PROXY empty string", {allProxy: ""}, false),
  ("only HTTP_PROXY", {httpProxy: proxy}, false),
  ("both ALL_PROXY spellings empty", {allProxy: "", all_proxy: ""}, false),
]

allProxyOnlyCases->Array.forEach(((name, env, expected)) => {
  test(`all-proxy-only warning predicate: ${name}`, () => isTruthy(allProxyOnly(env) == expected))
})

// The exact stderr line users see when only ALL_PROXY is set.
test("all-proxy-only warning text is exact", () =>
  isTextEqualTo(
    "Warning: ALL_PROXY/all_proxy is set but undici's EnvHttpProxyAgent does not route it — requests will connect directly. Set HTTP_PROXY/HTTPS_PROXY instead.",
    allProxyOnlyWarning,
  )
)
