/** String helper utilities used by text and other extractors.
  * All regex operations use %raw for ReScript v12 compatibility.
  */
let trimStr: string => string = text => String.trim(text)

let normalizeWhitespace: string => string = text =>
  text
  ->String.replaceRegExp(/\s+/g, " ")
  ->String.trim

let toLower: string => string = text => String.toLowerCase(text)

let toUpper: string => string = text => String.toUpperCase(text)

/** Extract first capture group of a regex pattern. Returns None when no match. */
let extractPattern: (string, string) => option<string> = (text, pattern) => {
  try {
    let result: option<string> = %raw(`
      (text, pattern) => {
        const match = new RegExp(pattern).exec(text);
        const [firstGroup] = match ?? [];
        if (firstGroup) return firstGroup;
        return undefined;
      }
    `)(text, pattern)->Obj.magic
    result
  } catch {
  | _ => None
  }
}

let stripNonNumeric: string => string = text => text->String.replaceRegExp(/[^0-9.\-]/g, "")
