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

/** Exact stderr line when a proxy variable is set but undici cannot be imported. */
let undiciUnavailableWarning = "Warning: HTTP_PROXY/http_proxy/HTTPS_PROXY/https_proxy/ALL_PROXY/all_proxy is set but undici is unavailable — proxy will be ignored. Install undici with: npm install undici"

/** Optional import is confined to this FFI island; undefined means unavailable. */
let loadEnvHttpProxyAgent: unit => promise<option<dispatcher>> = %raw(`async function() {
  try {
    var undici = await import('undici');
    return new undici.EnvHttpProxyAgent();
  } catch (e) {
    return undefined;
  }
}`)

/**
  * Loads the agent only after the gate, then reports at most one warning: the
  * ALL_PROXY-only note is irrelevant when undici itself is unavailable.
  */
let createEnvProxyDispatcherWith = async (~env, ~loadAgent, ~report) =>
  if !hasProxyEnv(env) {
    None
  } else {
    switch await loadAgent() {
    | Some(agent) =>
      if allProxyOnly(env) {
        report(allProxyOnlyWarning)
      }
      Some(agent)
    | None =>
      report(undiciUnavailableWarning)
      None
    }
  }

/**
  * Environment is inspected at fetch time. The warning prints at most once per
  * process because Fetcher caches this dispatcher in `proxyDispatcherPromise`.
  */
let createEnvProxyDispatcher = () =>
  createEnvProxyDispatcherWith(~env=environment, ~loadAgent=loadEnvHttpProxyAgent, ~report=line =>
    Console.error(line)
  )
