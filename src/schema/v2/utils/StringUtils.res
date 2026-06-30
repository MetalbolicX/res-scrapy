/** String helper utilities used by text and other extractors. */
let trimStr: string => string = text => String.trim(text)

let normalizeWhitespace: string => string = text =>
  text
  ->String.replaceRegExp(/\s+/g, " ")
  ->String.trim

let toLower: string => string = text => String.toLowerCase(text)

let toUpper: string => string = text => String.toUpperCase(text)

/* -------------------------------------------------------------------------- */
/* In-process regex execution.                                                */
/*                                                                            */
/* Previously, every regex call spawned a Node.js child process to avoid      */
/* catastrophic backtracking hanging the main event loop. We now run regex    */
/* in-process with two defenses:                                              */
/*   1. compileSafePattern rejects patterns known to be DoS-prone (backrefs,  */
/*      lookaheads, nested quantified groups, huge quantifiers, etc.).        */
/*   2. exec/test calls run synchronously in the parent thread — the safety   */
/*      net in step 1 keeps the surface small.                                */
/* -------------------------------------------------------------------------- */

let compileSafePattern: string => option<RegExp.t> = %raw(`
pattern => {
  if (!pattern || typeof pattern !== "string") return undefined;
  if (pattern.length > 200) return undefined;

  // Disallow backreferences: \1, \2, ...
  if (/\\[1-9][0-9]*/.test(pattern)) return undefined;

  // Disallow lookaheads/lookbehinds
  if (/\(\?[:=!<]/.test(pattern)) return undefined;

  // Disallow nested quantified groups (e.g. (a+)+, (a*)+, (a{1,3})*)
  if (/\([^)]*[+*?][^)]*\)\s*[+*?]/.test(pattern)) return undefined;
  if (/\([^)]*\{[^}]+\}[^)]*\)\s*[+*?]/.test(pattern)) return undefined;

  // Disallow quantified alternation groups (often expensive)
  if (/\((?:[^()]*\|){1,}[^()]*\)\s*[+*{]/.test(pattern)) return undefined;

  // Disallow very large explicit quantifiers
  if (/\{(?:\d{4,}|\d+,\d{4,}|\d{4,},)\}/.test(pattern)) return undefined;

  try {
    return new RegExp(pattern);
  } catch {
    return undefined;
  }
}
`)

@send external regexTest: (RegExp.t, string) => bool = "test"
@send external regexExec: (RegExp.t, string) => Null.t<array<string>> = "exec"

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

let extractPattern: (string, string) => option<string> = (text, pattern) =>
  runRegex(text, pattern)

let matchesPattern: (string, string) => bool = (text, pattern) =>
  switch compileSafePattern(pattern) {
  | None => false
  | Some(re) => regexTest(re, text)
  }

let stripNonNumeric: string => string = text => text->String.replaceRegExp(/[^0-9.\-]/g, "")