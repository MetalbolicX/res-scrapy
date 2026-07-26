/**
  * Bindings to the Node.js `node:util` module, scoped to the `parseArgs` API.
  *
  * `parseArgs` (available since Node 18.3 / our requirement ≥ 22) provides
  * first-class CLI argument parsing without external dependencies.
  */
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
  multiple?: bool,
}

/**
  * Parsed flag values returned by `parseArgs`.
  * All fields are optional because flags may be absent from the invocation.
 */
type cliValues = {
  help?: bool,
  version?: bool,
  selector?: string,
  mode?: bool,
  extract?: string,
  schema?: string,
  schemaPath?: string,
  table?: bool,
  output?: string,
  format?: string,
  url?: string,
  concurrency?: string,
  userAgent?: string,
  timeout?: string,
  retry?: string,
  delay?: string,
  header?: array<string>,
  cookie?: array<string>,
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

/** Serialises any value to a JSON string via the platform `JSON.stringify`. */
@val @scope("JSON") external jsonStringify: 'a => string = "stringify"

/** Parses a raw JSON string and returns `option<JSON.t>`, returning `None` on syntax errors. */
let jsonParse = (raw: string): option<JSON.t> => {
  try {
    Some((%raw("JSON.parse"): string => JSON.t)(raw))
  } catch {
  | _ => None
  }
}
