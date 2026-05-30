/** String helper utilities used by text and other extractors. */
let trimStr: string => string = text => String.trim(text)

let normalizeWhitespace: string => string = text =>
  text
  ->String.replaceRegExp(/\s+/g, " ")
  ->String.trim

let toLower: string => string = text => String.toLowerCase(text)

let toUpper: string => string = text => String.toUpperCase(text)

let regexEvalScript =
  "const mode = process.argv[1]; const text = process.argv[2]; const pattern = process.argv[3]; try { const re = new RegExp(pattern); if (mode === 'test') { process.stdout.write(re.test(text) ? '1' : '0'); } else { const match = re.exec(text); process.stdout.write(match ? match[0] : ''); } } catch { process.stdout.write(''); }"

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

let _makeArgs: (string, string, string, string, string) => array<string> = %raw(`
(a, b, c, d, e) => [a, b, c, d, e]
`)

let runRegexInChild = (~mode: string, ~text: string, ~pattern: string): option<string> => {
  switch compileSafePattern(pattern) {
  | None => None
  | Some(_) =>
    try {
      let args = _makeArgs("-e", regexEvalScript, mode, text, pattern)
      let output = NodeJsBinding.ChildProcess.execFileSync(
        NodeJsBinding.Process.execPath,
        args,
        {encoding: "utf8", timeout: 1000},
      )
      if output === "" {
        None
      } else {
        Some(output)
      }
    } catch {
    | _ => None
    }
  }
}

let extractPattern: (string, string) => option<string> = (text, pattern) => {
  switch runRegexInChild(~mode="extract", ~text, ~pattern) {
  | Some(output) => Some(output)
  | None => None
  }
}

let matchesPattern: (string, string) => bool = (text, pattern) =>
  switch runRegexInChild(~mode="test", ~text, ~pattern) {
  | Some("1") => true
  | _ => false
  }

let stripNonNumeric: string => string = text => text->String.replaceRegExp(/[^0-9.\-]/g, "")
