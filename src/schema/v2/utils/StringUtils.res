/** String helper utilities used by text and other extractors.
  * All regex operations use %raw for ReScript v12 compatibility.
  */

let trimStr: string => string = s => String.trim(s)

let normalizeWhitespace: string => string = %raw(`
  function(s) { return s.replace(/\s+/g, ' ').trim(); }
`)

let toLower: string => string = s => String.toLowerCase(s)

let toUpper: string => string = s => String.toUpperCase(s)

/** Extract first capture group of a regex pattern. Returns None when no match. */
let extractPattern: (string, string) => option<string> = %raw(`
  function(str, pattern) {
    try {
      var m = str.match(new RegExp(pattern));
      return (m && m[1] !== undefined) ? m[1] : undefined;
    } catch(_) { return undefined; }
  }
`)

let stripNonNumeric: string => string = %raw(`
  function(s) { return s.replace(/[^0-9.\-]/g, ''); }
`)

let replaceAll: (string, string, string) => string = %raw(`
  function(str, search, replacement) {
    return str.split(search).join(replacement);
  }
`)
