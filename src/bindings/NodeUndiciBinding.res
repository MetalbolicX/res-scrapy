/**
  * Dynamic import of undici's EnvHttpProxyAgent when uppercase/lowercase
  * proxy variables activate it. ALL_PROXY/all_proxy are gate-only inputs:
  * EnvHttpProxyAgent owns supported routing, precedence and bypass behavior.
  *
  * The dispatcher is created asynchronously because undici is an optional peer
  * dependency loaded only when a proxy is detected in the environment.
  */
type dispatcher

/** Only activation is decided here; routing and bypass belong to undici. */
type proxyEnv = {
  @as("HTTP_PROXY") httpProxy?: string,
  http_proxy?: string,
  @as("HTTPS_PROXY") httpsProxy?: string,
  https_proxy?: string,
  @as("ALL_PROXY") allProxy?: string,
  all_proxy?: string,
  @as("NO_PROXY") noProxy?: string,
  no_proxy?: string,
}

/** Pure predicate: callers/tests supply records, never mutate global env. */
let hasProxyEnv = (env: proxyEnv) => {
  let nonempty = value => value->Option.getOr("") != ""
  nonempty(env.httpProxy) ||
  nonempty(env.http_proxy) ||
  nonempty(env.httpsProxy) ||
  nonempty(env.https_proxy) ||
  nonempty(env.allProxy) ||
  nonempty(env.all_proxy)
}

@val @scope("process") external environment: proxyEnv = "env"

/** Optional import is confined to this FFI island and runs only after the gate. */
let createWhenEnabled: bool => promise<option<dispatcher>> = %raw(`async function(hasProxy) {
  if (!hasProxy) return undefined;
  try {
    var undici = await import('undici');
    return new undici.EnvHttpProxyAgent();
  } catch (e) {
    console.error("Warning: HTTP_PROXY/http_proxy/HTTPS_PROXY/https_proxy/ALL_PROXY/all_proxy is set but undici is unavailable — proxy will be ignored. Install undici with: npm install undici");
    return undefined;
  }
}`)

/** Environment is inspected at fetch time; Fetcher retains dispatcher caching. */
let createEnvProxyDispatcher = () => createWhenEnabled(hasProxyEnv(environment))
