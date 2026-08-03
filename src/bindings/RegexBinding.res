/**
  * Safe RegExp compilation with DoS-prevention guards.
  *
  * Rejects patterns containing features known to cause catastrophic backtracking:
  * backreferences, lookaheads/lookbehinds, nested quantified groups, and
  * large explicit quantifiers. Returns undefined for unsafe or invalid patterns.
  */
type compiledRegex

/** Compiles a regex pattern after running safety checks. Returns undefined on unsafe/invalid input. */
let compileSafePattern: string => option<compiledRegex> = %raw(`function(pattern) {
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
  } catch (e) {
    return undefined;
  }
}`)
