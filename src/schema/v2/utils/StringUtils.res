/** String helper utilities used by text and other extractors. */
let trimStr: string => string = text => String.trim(text)

let normalizeWhitespace: string => string = text =>
  text
  ->String.replaceRegExp(/\s+/g, " ")
  ->String.trim

let toLower: string => string = text => String.toLowerCase(text)

let toUpper: string => string = text => String.toUpperCase(text)

/* -------------------------------------------------------------------------- */
/* In-process regex execution. */
/*  */
/* Previously, every regex call spawned a Node.js child process to avoid */
/* catastrophic backtracking hanging the main event loop. We now run regex */
/* in-process with two defenses: */
/* 1. compileSafePattern rejects patterns known to be DoS-prone (backrefs, */
/* lookaheads, nested quantified groups, huge quantifiers, etc.). */
/* 2. exec/test calls run synchronously in the parent thread — the safety */
/* net in step 1 keeps the surface small. */
/* -------------------------------------------------------------------------- */

let compileSafePattern = RegexBinding.compileSafePattern

@send external regexTest: (RegexBinding.compiledRegex, string) => bool = "test"
@send external regexExec: (RegexBinding.compiledRegex, string) => Null.t<array<string>> = "exec"

/** Run an in-process regex match. Mirrors the prior child-process contract:
  * returns None when there is no match OR when the matched substring is empty
  * (matches the "if output === ''" branch in the old implementation). */
let runRegex: (string, string) => option<string> = (text, pattern) => {
  switch compileSafePattern(pattern) {
  | None => None
  | Some(re) =>
    switch regexExec(re, text)->Null.toOption {
    | None => None
    | Some(matches) =>
      switch matches[0] {
      | Some(m) =>
        if m === "" {
          None
        } else {
          Some(m)
        }
      | None => None
      }
    }
  }
}

let extractPattern: (string, string) => option<string> = (text, pattern) => runRegex(text, pattern)

let matchesPattern: (string, string) => bool = (text, pattern) =>
  switch compileSafePattern(pattern) {
  | None => false
  | Some(re) => regexTest(re, text)
  }

let stripNonNumeric: string => string = text => text->String.replaceRegExp(/[^0-9.\-]/g, "")
