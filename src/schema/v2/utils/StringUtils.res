/** String helper utilities used by text and other extractors. */
let trimStr: string => string = text => String.trim(text)

let normalizeWhitespace: string => string = text =>
  text
  ->String.replaceRegExp(/\s+/g, " ")
  ->String.trim

let toLower: string => string = text => String.toLowerCase(text)

let toUpper: string => string = text => String.toUpperCase(text)

/** Extract first capture group of a regex pattern. Returns None when no match. */
@get_index external getMatchAt: (RegExp.Result.t, int) => option<string> = ""

let extractPattern: (string, string) => option<string> = (text, pattern) => {
  try {
    RegExp.fromString(pattern)
    ->RegExp.exec(text)
    ->Option.flatMap(res => getMatchAt(res, 0))
  } catch {
  | _ => None
  }
}

let stripNonNumeric: string => string = text => text->String.replaceRegExp(/[^0-9.\-]/g, "")
