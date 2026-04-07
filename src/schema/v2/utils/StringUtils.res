/** String helper utilities used by text and other extractors.
  * All regex operations use %raw for ReScript v12 compatibility.
  */
let trimStr: string => string = text => String.trim(text)

let normalizeWhitespace: string => string = %raw(`
  (text) => text.replace(/\s+/g, ' ').trim()
`)

let toLower: string => string = text => String.toLowerCase(text)

let toUpper: string => string = text => String.toUpperCase(text)

/** Extract first capture group of a regex pattern. Returns None when no match. */
let extractPattern: (string, string) => option<string> = %raw(`
  (str, pattern) => {
    try {
      const match = str.match(new RegExp(pattern));
      return (match && match[1] !== undefined) ? match[1] : undefined;
    } catch(_) {
      return undefined;
    }
  }
`)

let stripNonNumeric: string => string = %raw(`
  (s) => s.replace(/[^0-9.\-]/g, '')
`)

let replaceAll: (string, string, string) => string = %raw(`
  (str, search, replacement) => str.split(search).join(replacement)
`)
