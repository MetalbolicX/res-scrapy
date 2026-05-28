open Test
open Assertions

test("production context contains all dependencies", () => {
  let ctx = AppContext.production
  // Use typeof checks instead of equality for function references
  isTruthy(%raw(`ctx => typeof ctx.deps.parseCli === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.deps.validateArgs === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.deps.readStdin === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.deps.extractTable === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.deps.loadSchema === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.deps.applySchema === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.deps.writeFile === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.deps.appendFile === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.deps.writeFileSync === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.deps.appendFileSync === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.deps.stringifyJson === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.deps.stringifyTableRows === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.deps.stringifyStrings === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.deps.parseTemplate === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.deps.fetchAll === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.deps.getCliVersion === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.deps.performanceNow === 'function'`)(ctx))
})

test("production context contains all IO functions", () => {
  let ctx = AppContext.production
  isTruthy(%raw(`ctx => typeof ctx.io.out === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.io.err === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.io.warn === 'function'`)(ctx))
  isTruthy(%raw(`ctx => typeof ctx.io.exit === 'function'`)(ctx))
})
