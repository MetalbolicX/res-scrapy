/**
  * Dynamic import of undici's EnvHttpProxyAgent when uppercase/lowercase
  * proxy variables activate it. ALL_PROXY/all_proxy are gate-only inputs:
  * EnvHttpProxyAgent owns supported routing, precedence and bypass behavior.
  *
  * The dispatcher is created asynchronously because undici is an optional peer
  * dependency loaded only when a proxy is detected in the environment.
  */
type dispatcher

/** Nonempty env values alone activate the gate; routing belongs to undici. */
let isNonempty = value => value->Option.getOr("") != ""

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
  isNonempty(env.httpProxy) ||
  isNonempty(env.http_proxy) ||
  isNonempty(env.httpsProxy) ||
  isNonempty(env.https_proxy) ||
  isNonempty(env.allProxy) ||
  isNonempty(env.all_proxy)
}

/**
  * Pure predicate: ALL_PROXY/all_proxy is set but no proxy variable that
  * undici's EnvHttpProxyAgent actually routes is. Such a run keeps the agent
  * loaded yet sends every request direct, so the caller must warn.
  */
let allProxyOnly = (env: proxyEnv) => {
  let hasAllProxy = isNonempty(env.allProxy) || isNonempty(env.all_proxy)
  let hasRoutedProxy =
    isNonempty(env.httpProxy) ||
    isNonempty(env.http_proxy) ||
    isNonempty(env.httpsProxy) ||
    isNonempty(env.https_proxy)
  hasAllProxy && !hasRoutedProxy
}

/** Exact stderr line for the silently-unrouted ALL_PROXY case. */
let allProxyOnlyWarning = "Warning: ALL_PROXY/all_proxy is set but undici's EnvHttpProxyAgent does not route it — requests will connect directly. Set HTTP_PROXY/HTTPS_PROXY instead."

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

/**
  * Environment is inspected at fetch time. The warning prints at most once per
  * process because Fetcher caches this dispatcher in `proxyDispatcherPromise`.
  */
let createEnvProxyDispatcher = () => {
  let env = environment
  let enabled = hasProxyEnv(env)
  if enabled && allProxyOnly(env) {
    Console.error(allProxyOnlyWarning)
  }
  createWhenEnabled(enabled)
}
