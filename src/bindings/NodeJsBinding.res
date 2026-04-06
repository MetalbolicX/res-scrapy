/**
  * Bindings to the Node.js `process` global.
  *
  * Only the surface needed by this CLI is exposed. Extend here when new
  * `process.*` APIs are required rather than adding ad-hoc `%raw` calls.
 */
module Process = {
  /** Terminates the process with the given numeric exit code. */
  @val @scope("process") external exit: int => unit = "exit"

  /** The command-line argument vector; `argv[0]` is `node`, `argv[1]` is the script. */
  @val @scope("process") external argv: array<string> = "argv"

  /**
    * Represents the `process.stdin` readable stream.
    *
    * `isTTY` is `Some(true)` when stdin is a terminal (interactive), `None`
    * when it is a pipe or redirected file — used to detect piped input.
   */
  type stdInput = {
    isTTY?: bool,
  }

  /** A reference to `process.stdin`. */
  @val @scope("process") external stdin: stdInput = "stdin"

  /** Listens for `"data"` events, invoking `cb` with each UTF-8 chunk. */
  @send external onData: (stdInput, @as("data") _, string => unit) => unit = "on"

  /** Listens for the `"end"` event, invoked once the stream is fully consumed. */
  @send external onEnd: (stdInput, @as("end") _, unit => unit) => unit = "on"

  /** Listens for `"error"` events on the stream. */
  @send external onError: (stdInput, @as("error") _, JsExn.t => unit) => unit = "on"

  /** Resumes a paused readable stream, allowing data events to flow. */
  @send external resume: stdInput => unit = "resume"

  /** Sets the character encoding for data events (e.g. `"utf8"`). */
  @send external setEncoding: (stdInput, string) => unit = "setEncoding"
}

/**
  * Bindings to the Node.js `node:util` module, scoped to the `parseArgs` API.
  *
  * `parseArgs` (available since Node 18.3 / our requirement ≥ 22) provides
  * first-class CLI argument parsing without external dependencies.
 */
module Util = {
  /**
    * @unboxed union for the `default` field of a flag configuration.
    *
    * `parseArgs` accepts either a string or a boolean default; the `@unboxed`
    * attribute erases the variant wrapper at runtime so the JS value is passed
    * through unchanged.
   */
  @unboxed
  type defaultValue =
    | String(string)
    | Bool(bool)

  /**
    * Per-flag configuration passed inside the `options` dictionary of `parseConfig`.
    *
    * - `type_`   — `"string"` or `"boolean"` (the `@as("type")` attribute maps
    *               this field to the JS key `"type"`, avoiding the reserved word).
    * - `short`   — optional single-character alias (e.g. `"s"` for `--selector`).
    * - `default` — optional default value; omit to make the flag undefined when absent.
   */
  type flagConfig = {
    @as("type") type_: string,
    short?: string,
    default?: defaultValue,
  }

  /**
    * Parsed flag values returned by `parseArgs`.
    * All fields are optional because flags may be absent from the invocation.
   */
  type cliValues = {
    help?: bool,
    selector?: string,
    mode?: bool,
    extract?: string,
    schema?: string,
    schemaPath?: string,
  }

  /**
    * The return type of `parseArgs`.
    *
    * - `values`      — the parsed flag values object.
    * - `positionals` — remaining non-flag arguments (`allowPositionals` must be `true`).
   */
  type parseResults = {
    values: cliValues,
    positionals: array<string>,
  }

  /**
    * Input configuration for `parseArgs`.
    *
    * - `args`             — the raw argument array (typically `process.argv.slice(2)`).
    * - `options`          — a dictionary of flag name → `flagConfig`.
    * - `strict`           — when `true`, throws on unknown flags.
    * - `allowPositionals` — when `true`, non-flag tokens are collected into `positionals`.
    * - `tokens`           — when `true`, also returns a low-level token array (unused here).
   */
  type parseConfig = {
    args: array<string>,
    options: dict<flagConfig>,
    strict?: bool,
    allowPositionals?: bool,
    tokens?: bool,
  }

  /** Parses `config.args` according to `config.options` and returns `parseResults`. */
  @module("node:util") external parseArgs: parseConfig => parseResults = "parseArgs"
}

/** Serialises any value to a JSON string via the platform `JSON.stringify`. */
@val @scope("JSON") external jsonStringify: 'a => string = "stringify"

/** Parses a raw JSON string and returns `option<'a>`, returning `None` on syntax errors. */
let jsonParse = (raw: string): option<'a> => {
  try {
    Some((%raw("JSON.parse"): string => 'a)(raw))
  } catch {
  | _ => None
  }
}

/** Node.js `fs` module — synchronous file-system access used for schema loading. */
module Fs = {
  /** Reads a file synchronously, returning its contents as a `string`. Raises if the path does not exist. */
  @module("node:fs") external readFileSync: (string, @as("utf8") _) => string = "readFileSync"
}

/** Node.js `node:url` module — URL parsing, resolution, and formatting. */
module Url = {
  /** URL object returned by the URL constructor. */
  type urlObj = {
    href: string,
    protocol: string,
    hostname: string,
    pathname: string,
    search: string,
    hash: string,
  }

  /** Parse and resolve a URL against an optional base URL.
    * `new URL(relative, base)` resolves relative URLs; `new URL(absolute)` parses an absolute URL. */
  @new @module("node:url") external make: (string, option<string>) => urlObj = "URL"
}
