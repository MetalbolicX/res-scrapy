/**
  * Dynamic import of undici's EnvHttpProxyAgent for HTTP_PROXY/HTTPS_PROXY/ALL_PROXY support.
  *
  * The dispatcher is created asynchronously because undici is an optional peer
  * dependency loaded only when a proxy is detected in the environment.
  */
type dispatcher

/** Creates an undici EnvHttpProxyAgent if a proxy env var is set; returns undefined otherwise. */
let createEnvProxyDispatcher: unit => promise<option<dispatcher>> = %raw(`async function() {
  var hasProxy = Boolean(
    process.env.HTTP_PROXY ||
    process.env.HTTPS_PROXY ||
    process.env.ALL_PROXY
  );
  if (!hasProxy) return undefined;
  try {
    var undici = await import('undici');
    return new undici.EnvHttpProxyAgent();
  } catch (e) {
    console.error("Warning: HTTP_PROXY/HTTPS_PROXY/ALL_PROXY is set but undici is unavailable — proxy will be ignored. Install undici with: npm install undici");
    return undefined;
  }
}`)
