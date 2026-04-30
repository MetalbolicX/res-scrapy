/**
  * Parses URL templates with range expansion syntax.
  *
  * Supports three formats:
  * - `{1..10}` — plain range with step 1
  * - `{0..100..10}` — range with explicit step
  * - `{001..050}` — zero-padded range (width inferred from start)
  *
  * Examples:
  * ```rescript
  * parse("https://api.com/page={1..3}")
  * // → Ok(["https://api.com/page=1", "https://api.com/page=2", "https://api.com/page=3"])
  *
  * parse("https://api.com/offset={0..20..10}")
  * // → Ok(["https://api.com/offset=0", "https://api.com/offset=10", "https://api.com/offset=20"])
  *
  * parse("https://api.com/page={001..003}")
  * // → Ok(["https://api.com/page=001", "https://api.com/page=002", "https://api.com/page=003"])
  * ```
  */

type parseError =
  | InvalidSyntax(string)
  | InvalidRange(string)
  | MultipleTemplates(string)

/**
  * Parses a URL template and expands it into an array of URLs.
  *
  * If no template is present (no `{...}`), returns a single-element array with the original URL.
  */
let parse: string => result<array<string>, parseError>

/**
  * Converts a parseError to a human-readable string.
  */
let parseErrorToMessage: parseError => string
