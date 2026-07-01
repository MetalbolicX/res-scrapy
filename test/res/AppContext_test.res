open Test
open Assertions

/** Approval test: spec says "All dependencies remain accessible" via sub-records.
    These tests reference the new grouped shape (ctx.deps.cli.*, ctx.deps.fs.*, ...)
    which exercises grouped access as documented in the spec scenario. */
test("cli sub-record exposes parseCli, validateArgs, readStdin, getCliVersion", () => {
  let ctx = AppContext.production
  isTruthy(%raw(`ctx => typeof ctx.deps.cli.parseCli === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.deps.cli.validateArgs === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.deps.cli.readStdin === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.deps.cli.getCliVersion === 'function'`)(ctx))
})

test("fs sub-record exposes writeFile, appendFile, writeFileSync, appendFileSync", () => {
  let ctx = AppContext.production
  isTruthy(%raw(`ctx => typeof ctx.deps.fs.writeFile === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.deps.fs.appendFile === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.deps.fs.writeFileSync === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.deps.fs.appendFileSync === 'function'`)(ctx))
})

test("serialize sub-record exposes stringifyJson, stringifyTableRows, stringifyStrings", () => {
  let ctx = AppContext.production
  isTruthy(%raw(`ctx => typeof ctx.deps.serialize.stringifyJson === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.deps.serialize.stringifyTableRows === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.deps.serialize.stringifyStrings === 'function'`)(ctx))
})

test("doc sub-record exposes documentOps, extractTable, parseTemplate", () => {
  let ctx = AppContext.production
  // documentOps is a record, not a function
  isTruthy(
    %raw(`ctx => ctx.deps.doc.documentOps !== undefined && typeof ctx.deps.doc.documentOps === 'object'`)(
      ctx,
    ),
  )
  isTruthy(%raw(`ctx => typeof ctx.deps.doc.extractTable === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.deps.doc.parseTemplate === 'function'`)(ctx))
})

test("schema sub-record exposes loadSchema, applySchema", () => {
  let ctx = AppContext.production
  isTruthy(%raw(`ctx => typeof ctx.deps.schema.loadSchema === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.deps.schema.applySchema === 'function'`)(ctx))
})

test("fetch sub-record exposes fetchAll", () => {
  let ctx = AppContext.production
  isTruthy(%raw(`ctx => typeof ctx.deps.fetch.fetchAll === 'function'`)(ctx))
})

test("perf sub-record exposes performanceNow", () => {
  let ctx = AppContext.production
  isTruthy(%raw(`ctx => typeof ctx.deps.perf.performanceNow === 'function'`)(ctx))
})

/** Behavior preservation: perf sub-record function returns a finite number (non-side-effecting). */
test("perf.performanceNow returns a finite number", () => {
  let ctx = AppContext.production
  let now = ctx.deps.perf.performanceNow()
  isTruthy(%raw(`n => typeof n === 'number' && Number.isFinite(n) && n >= 0`)(now))
})

/** Behavior preservation: Grouped getCliVersion is callable (no args, returns string).
    parseCli is NOT called here because it reads process.argv which contains the test runner args. */
test("cli.getCliVersion returns a non-empty string", () => {
  let ctx = AppContext.production
  let v = ctx.deps.cli.getCliVersion()
  isTruthy(%raw(`v => typeof v === 'string' && v.length > 0`)(v))
})

/** Behavior preservation: IO sub-record stays unchanged (out, err, warn, exit). */
test("production context contains all IO functions", () => {
  let ctx = AppContext.production
  isTruthy(%raw(`ctx => typeof ctx.io.out === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.io.err === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.io.warn === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.io.exit === 'function'`)(ctx))
})

/** Behavior preservation: legacy flat paths must NOT exist on deps (full migration). */
test("deps no longer carries legacy flat fields", () => {
  let ctx = AppContext.production
  isTruthy(%raw(`ctx => ctx.deps.parseCli === undefined`)(ctx))
  isTruthy(%raw(`ctx => ctx.deps.fetchAll === undefined`)(ctx))
  isTruthy(%raw(`ctx => ctx.deps.writeFile === undefined`)(ctx))
  isTruthy(%raw(`ctx => ctx.deps.stringifyJson === undefined`)(ctx))
  isTruthy(%raw(`ctx => ctx.deps.documentOps === undefined`)(ctx))
  isTruthy(%raw(`ctx => ctx.deps.loadSchema === undefined`)(ctx))
  isTruthy(%raw(`ctx => ctx.deps.performanceNow === undefined`)(ctx))
})
