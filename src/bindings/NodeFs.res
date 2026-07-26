/**
  * Node.js `fs` module — synchronous file-system access used for schema loading.
  *
  * Note: `readFileSync` uses the encoding from the binding (always "utf8").
  * `writeFileSync` replaces existing contents atomically.
  */
/** Reads a file synchronously, returning its contents as a UTF-8 `string`. */
@module("node:fs") external readFileSync: (string, @as("utf8") _) => string = "readFileSync"

/** Writes text content to a file synchronously, replacing existing contents. */
@module("node:fs") external writeFileSync: (string, string) => unit = "writeFileSync"

/** Appends text to a file synchronously (creates file if it doesn't exist). */
@module("node:fs") external appendFileSync: (string, string) => unit = "appendFileSync"

/** Writes text content to a file asynchronously. */
@module("node:fs/promises") external writeFile: (string, string) => promise<unit> = "writeFile"

/** Appends text to a file asynchronously (creates file if it doesn't exist). */
@module("node:fs/promises") external appendFile: (string, string) => promise<unit> = "appendFile"
