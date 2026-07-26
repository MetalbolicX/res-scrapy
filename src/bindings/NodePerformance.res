/** Bindings to `performance.now()` for high-resolution timing. */
/** Returns the current high-resolution timestamp in milliseconds since time origin. */
@val @scope("performance") external now: unit => float = "now"
