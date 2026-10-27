/**
  * Bindings to the Node.js `process` global.
  *
  * Only the surface needed by this CLI is exposed. Extend here when new
  * `process.*` APIs are required rather than adding ad-hoc `%raw` calls.
  */
/** Terminates the process with the given numeric exit code. */
@val @scope("process") external exit: int => unit = "exit"

/** Sets `process.exitCode` so Node exits naturally after pending writes complete. */
let setExitCode: int => unit = %raw(`code => { process.exitCode = code; }`)

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

/** The absolute path to the current Node.js executable. */
@val @scope("process") external execPath: string = "execPath"

/** Listens for `"data"` events, invoking `cb` with each UTF-8 chunk. */
@send external onData: (stdInput, @as("data") _, string => unit) => unit = "on"

/** Listens for the `"end"` event, invoked once the stream is fully consumed. */
@send external onEnd: (stdInput, @as("end") _, unit => unit) => unit = "on"

/** Listens for `"error"` events on the stream. */
@send external onError: (stdInput, @as("error") _, JsExn.t => unit) => unit = "on"

/** Resumes a paused readable stream, allowing data events to flow. */
@send external resume: stdInput => unit = "resume"

/** Stop flow without destroying a stream owned by the process/caller. */
@send external pause: stdInput => unit = "pause"
@send
external removeDataListener: (stdInput, @as("data") _, string => unit) => unit = "removeListener"
@send external removeEndListener: (stdInput, @as("end") _, unit => unit) => unit = "removeListener"
@send
external removeErrorListener: (stdInput, @as("error") _, JsExn.t => unit) => unit = "removeListener"
/** UTF-8 byte count, independent of JS UTF-16 string length. */
@val @scope("Buffer") external utf8ByteLength: (string, @as("utf8") _) => int = "byteLength"

/** Sets the character encoding for data events (e.g. `"utf8"`). */
@send external setEncoding: (stdInput, string) => unit = "setEncoding"
/** Test-only owned PassThrough fixtures. Raw interop is confined here so tests
    never mutate process.stdin or global timers. Sentinel listeners belong to
    the fixture, not the reader, and setup faults exercise partial cleanup. */
module TestSupport = {
  type t
  @module("node:stream") @new external makePassThrough: unit => stdInput = "PassThrough"
  let wrap: (stdInput, option<bool>, option<string>) => t = %raw(`(stream, tty, failAt) => {
    stream.isTTY = tty;
    const state = { stream, sentinelEnds: 0, sentinelErrors: 0, resumes: 0 };
    stream.on('end', () => { state.sentinelEnds++; });
    stream.on('error', () => { state.sentinelErrors++; });
    const on = stream.on;
    stream.on = function(event, cb) {
      if (failAt === event) throw new Error('fixture ' + event);
      return on.call(this, event, cb);
    };
    const encoding = stream.setEncoding;
    stream.setEncoding = function(value) {
      if (failAt === 'encoding') throw new Error('fixture encoding');
      return encoding.call(this, value);
    };
    const resume = stream.resume;
    stream.resume = function() {
      state.resumes++;
      if (failAt === 'resume') throw new Error('fixture resume');
      return resume.call(this);
    };
    return state;
  }`)
  let make = (~tty=?, ~failAt=?, ()) => wrap(makePassThrough(), tty, failAt)
  @get external stream: t => stdInput = "stream"
  @get external sentinelEnds: t => int = "sentinelEnds"
  @get external sentinelErrors: t => int = "sentinelErrors"
  @get external resumes: t => int = "resumes"
  @send external write: (stdInput, string) => unit = "write"
  @send external end_: stdInput => unit = "end"
  @send external destroy: stdInput => unit = "destroy"
  @send external listenerCount: (stdInput, string) => int = "listenerCount"
  let paused: stdInput => bool = %raw(`stream => stream.readableFlowing === false`)
  let emitError: (
    stdInput,
    string,
  ) => unit = %raw(`(stream, message) => { stream.emit('error', new Error(message)); }`)
  let lateEvents: stdInput => unit = %raw(`stream => {
    stream.emit('data', 'late'); stream.emit('end'); stream.emit('error', new Error('late'));
  }`)
}

/* -------------------------------------------------------------------------- */
/* Flush-before-exit — bounded stdout drain for fatal exits. */
/* -------------------------------------------------------------------------- */

/** Minimal writable-stream surface needed to flush buffered output. */
type writable

/** Bytes buffered in the stream but not yet handed to the operating system. */
@get external writableLength: writable => int = "writableLength"

/** Writes a chunk; `cb` fires once that chunk and every earlier write landed. */
@send external writeChunk: (writable, string, unit => unit) => bool = "write"

type flushTimer
external scheduleTimeout: (unit => unit, int) => flushTimer = "setTimeout"
external cancelTimeout: flushTimer => unit = "clearTimeout"

/** `process.stdout`, the stream whose buffered bytes must flush before exit. */
@val @scope("process") external stdout: writable = "stdout"

/** Runs `exitFn(code)` exactly once: immediately when nothing is buffered,
  * otherwise after a zero-length write callback flushes earlier writes, with
  * `graceMs` as the upper bound. Does not set `process.exitCode`. */
let exitWhenFlushed = (stream: writable, exitFn: int => unit, graceMs: int, code: int): unit => {
  let exited = ref(false)
  let exitOnce = () =>
    if !exited.contents {
      exited.contents = true
      exitFn(code)
    }
  if stream->writableLength == 0 {
    exitOnce()
  } else {
    let timer = scheduleTimeout(() => exitOnce(), graceMs)
    stream
    ->writeChunk("", () => {
      timer->cancelTimeout
      exitOnce()
    })
    ->ignore
  }
}

/** Production exit path: flush `process.stdout` (bounded to 2 s), then exit. */
let exitAfterFlush = (code: int): unit => exitWhenFlushed(stdout, code => exit(code), 2000, code)

/* -------------------------------------------------------------------------- */
/* Global runtime event handlers — typed wrapper around a %raw FFI island. */
/* -------------------------------------------------------------------------- */

/** Registers global Node.js event handlers for uncaught exceptions, unhandled
  * rejections, and termination signals. Guards against double-registration via
  * a globalThis flag.
  *
  * - `reporter` — callback invoked with each error message.
  * - `exitFn`   — callback invoked with the desired exit code on fatal events;
  *                production passes `exitAfterFlush` so buffered stdout drains
  *                before the process terminates.
  */
let registerGlobalRuntimeHandlers: (
  string => unit,
  int => unit,
) => unit = %raw(`function(report, exitFn) {
  if (globalThis.__resScrapyRuntimeHandlersRegistered) {
    return;
  }
  globalThis.__resScrapyRuntimeHandlersRegistered = true;

  var formatError = function(value) {
    if (value && typeof value === "object") {
      if (typeof value.stack === "string") return value.stack;
      if (typeof value.message === "string") return value.message;
    }
    return String(value);
  };

  process.on("uncaughtException", function(err) {
    report("Unexpected runtime error:");
    report(formatError(err));
    exitFn(1);
  });

  process.on("unhandledRejection", function(reason) {
    report("Unhandled promise rejection:");
    report(formatError(reason));
    exitFn(1);
  });

  process.on("SIGINT", function() {
    report("Interrupted (SIGINT)");
    exitFn(130);
  });

  process.on("SIGTERM", function() {
    report("Terminated (SIGTERM)");
    exitFn(143);
  });
}`)
