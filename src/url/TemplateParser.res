type parseError =
  | InvalidSyntax(string)
  | InvalidRange(string)
  | UrlCountExceeded(int) // actual count, cap applied

/**
  * Extracts template tokens from a URL template string.
  * Returns (prefix, templateContent, suffix).
  */
let extractTemplate: string => option<(string, string, string)> = url => {
  let openIndex = String.indexOf(url, "{")
  let closeIndex = String.indexOf(url, "}")

  if openIndex == -1 || closeIndex == -1 {
    None
  } else if closeIndex < openIndex {
    None
  } else {
    // Check for multiple templates
    let afterClose = String.slice(url, ~start=closeIndex + 1, ~end=String.length(url))
    if String.includes(afterClose, "{") || String.includes(afterClose, "}") {
      None
    } else {
      let prefix = String.slice(url, ~start=0, ~end=openIndex)
      let content = String.slice(url, ~start=openIndex + 1, ~end=closeIndex)
      let suffix = String.slice(url, ~start=closeIndex + 1, ~end=String.length(url))
      Some((prefix, content, suffix))
    }
  }
}

/**
  * Parses template content like "1..10" or "0..100..10" into (start, end, step, zeroPad).
  */
let parseRange: string => result<(int, int, int, int), parseError> = content => {
  let parts = String.split(content, "..")
  switch parts {
  | [startStr, endStr] => {
      // Plain range: {1..10}
      let startOpt = Int.fromString(startStr)
      let endOpt = Int.fromString(endStr)
      switch (startOpt, endOpt) {
      | (Some(start), Some(end_)) if start <= end_ => {
          // Detect zero-padding from start string
          let zeroPad = if String.startsWith(startStr, "0") && String.length(startStr) > 1 {
            String.length(startStr)
          } else {
            0
          }
          Ok((start, end_, 1, zeroPad))
        }
      | (Some(start), Some(end_)) if start > end_ =>
        Error(
          InvalidRange(
            `Range start (${Int.toString(start)}) must be <= end (${Int.toString(end_)})`,
          ),
        )
      | _ => Error(InvalidSyntax(`Invalid range syntax: "${content}"`))
      }
    }
  | [startStr, endStr, stepStr] => {
      // Range with step: {0..100..10}
      let startOpt = Int.fromString(startStr)
      let endOpt = Int.fromString(endStr)
      let stepOpt = Int.fromString(stepStr)
      switch (startOpt, endOpt, stepOpt) {
      | (Some(start), Some(end_), Some(step)) if start <= end_ && step > 0 => {
          // Detect zero-padding from start string
          let zeroPad = if String.startsWith(startStr, "0") && String.length(startStr) > 1 {
            String.length(startStr)
          } else {
            0
          }
          Ok((start, end_, step, zeroPad))
        }
      | (Some(_), Some(_), Some(step)) if step <= 0 =>
        Error(InvalidRange(`Step must be > 0, got ${Int.toString(step)}`))
      | (Some(start), Some(end_), Some(_)) if start > end_ =>
        Error(
          InvalidRange(
            `Range start (${Int.toString(start)}) must be <= end (${Int.toString(end_)})`,
          ),
        )
      | _ => Error(InvalidSyntax(`Invalid range syntax: "${content}"`))
      }
    }
  | _ => Error(InvalidSyntax(`Invalid range syntax: "${content}"`))
  }
}

/**
  * Maximum number of URLs that can be generated from a single template.
  * Prevents OOM from unbounded range expansions (e.g. {0..1000000000}).
  */
let maxUrls = 100_000

/**
  * Generates a sequence of integers from start to end (inclusive) with the given step.
  * Returns an error if the sequence exceeds maxUrls.
  */
let generateSequence: (int, int, int) => result<array<int>, parseError> = (start, end_, step) => {
  let count = (end_ - start) / step + 1
  if count > maxUrls {
    Error(UrlCountExceeded(count))
  } else {
    let current = ref(start)
    let acc = []
    while current.contents <= end_ {
      acc->Array.push(current.contents)
      current := current.contents + step
    }
    Ok(acc)
  }
}

/**
  * Zero-pads a number to the given width.
  */
let padZero: (int, int) => string = (num, width) => {
  if width <= 0 {
    Int.toString(num)
  } else {
    let str = Int.toString(num)
    let padding = max(0, width - String.length(str))
    String.repeat("0", padding) ++ str
  }
}

/**
  * Parses a URL template and expands it into an array of URLs.
  */
let parse: string => result<array<string>, parseError> = url => {
  switch extractTemplate(url) {
  | None => // No template found; check for stray braces
    if String.includes(url, "{") || String.includes(url, "}") {
      Error(InvalidSyntax("URL contains unmatched or multiple template braces"))
    } else {
      Ok([url])
    }
  | Some((prefix, content, suffix)) => switch parseRange(content) {
    | Error(e) => Error(e)
    | Ok((start, end_, step, zeroPad)) => switch generateSequence(start, end_, step) {
      | Error(e) => Error(e)
      | Ok(sequence) => {
          let urls = sequence->Array.map(num => {
            let numStr = padZero(num, zeroPad)
            prefix ++ numStr ++ suffix
          })
          Ok(urls)
        }
      }
    }
  }
}

/**
  * Converts a parseError to a human-readable string.
  */
let parseErrorToMessage: parseError => string = err => {
  switch err {
  | InvalidSyntax(msg) => `Invalid template syntax: ${msg}`
  | InvalidRange(msg) => `Invalid range: ${msg}`
  | UrlCountExceeded(count) =>
    `URL template would generate ${Int.toString(
        count,
      )} URLs, which exceeds the maximum of ${Int.toString(
        maxUrls,
      )}. Reduce the range or split into multiple templates.`
  }
}
