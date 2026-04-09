"use strict";

/**
 * Parse an ISO-8601 date/time string into a Date object.
 *
 * Uses the built-in Date constructor to parse the input string. If the input
 * cannot be parsed into a valid date, the function returns undefined.
 *
 * @param {string} s - An ISO-8601 formatted date/time string.
 * @returns {Date|undefined} The parsed Date object, or undefined if invalid.
 *
 * @example
 * ```JavaScript
 * parseISO("2024-06-01T12:34:56Z"); // returns a Date object representing June 1, 2024 at 12:34:56 UTC
 * parseISO("invalid-date"); // returns undefined
 * ```
 */
const parseISO = (s) => {
  const d = new Date(s);
  return Number.isNaN(d.getTime()) ? undefined : d;
};

/**
 * Parse an epoch timestamp given in seconds and return a Date object.
 *
 * The input is parsed using parseInt(..., 10) to obtain whole seconds, then
 * multiplied by 1000 to convert to milliseconds before constructing a Date.
 * If parsing fails or the resulting Date is invalid, undefined is returned.
 *
 * @param {string|number} s - Epoch seconds as a decimal string or number.
 * @returns {Date|undefined} A Date representing the given epoch seconds, or undefined on invalid input.
 */
const parseEpochSeconds = (s) => {
  const n = parseInt(s, 10);
  if (Number.isNaN(n)) return undefined;
  const d = new Date(n * 1000);
  return Number.isNaN(d.getTime()) ? undefined : d;
};

/**
 * Parse an epoch millisecond value and return a Date object.
 *
 * @param {string|number} s - Epoch milliseconds as a string or number (parsed with parseInt(s, 10)).
 * @returns {Date|undefined} A Date constructed from the parsed milliseconds, or undefined if parsing fails or the Date is invalid.
 */
const parseEpochMillis = (s) => {
  const n = parseInt(s, 10);
  if (Number.isNaN(n)) return undefined;
  const d = new Date(n);
  return Number.isNaN(d.getTime()) ? undefined : d;
};

/* --- constants --- */
const MONTHS_FULL = [
  "january",
  "february",
  "march",
  "april",
  "may",
  "june",
  "july",
  "august",
  "september",
  "october",
  "november",
  "december",
];
const MONTHS_ABBR = [
  "jan",
  "feb",
  "mar",
  "apr",
  "may",
  "jun",
  "jul",
  "aug",
  "sep",
  "oct",
  "nov",
  "dec",
];

const BASE_TOKENS = [
  { token: "yyyy", regex: "(\\d{4})", group: "year4" },
  { token: "yy", regex: "(\\d{2})", group: "year2" },
  { token: "MMMM", regex: "([A-Za-z]+)", group: "monthFull" },
  { token: "MMM", regex: "([A-Za-z]{3})", group: "monthAbbr" },
  { token: "MM", regex: "(\\d{1,2})", group: "month2" },
  { token: "M", regex: "(\\d{1,2})", group: "month1" },
  { token: "dd", regex: "(\\d{1,2})", group: "day2" },
  { token: "d", regex: "(\\d{1,2})", group: "day1" },
  { token: "HH", regex: "(\\d{1,2})", group: "hour24_2" },
  { token: "H", regex: "(\\d{1,2})", group: "hour24_1" },
  { token: "hh", regex: "(\\d{1,2})", group: "hour12_2" },
  { token: "h", regex: "(\\d{1,2})", group: "hour12_1" },
  { token: "mm", regex: "(\\d{1,2})", group: "min2" },
  { token: "m", regex: "(\\d{1,2})", group: "min1" },
  { token: "ss", regex: "(\\d{1,2})", group: "sec2" },
  { token: "s", regex: "(\\d{1,2})", group: "sec1" },
  { token: "a", regex: "(am|pm|AM|PM)", group: "ampm" },
];

/* --- build regex from format --- */
/**
 * Build a regular expression and capture-group mapping from a date format string.
 *
 * The function scans the provided format string `fmt`, replacing known format tokens
 * (defined in `BASE_TOKENS`) with their corresponding regex fragments while collecting
 * the associated group identifiers. Tokens are matched using a token-list sorted by
 * descending token length to avoid partial matches. Characters that are not recognized
 * tokens are escaped with `escapeRegexChar`. The assembled pattern is wrapped with
 * anchors (`^` and `$`) and compiled into a case-insensitive `RegExp`.
 *
 * If RegExp compilation fails, the function returns `{ re: null, groups: [] }`.
 *
 * @param {string} fmt - Date format template (e.g. "YYYY-MM-DD HH:mm") containing tokens present in BASE_TOKENS.
 * @returns {{ re: RegExp | null, groups: Array<*> }} An object containing:
 *   - re: the compiled RegExp (case-insensitive) matching the entire input, or null on compilation error.
 *   - groups: an ordered array of group identifiers corresponding to the capturing groups produced by the regex.
 */
const buildRegexFromFormat = (fmt) => {
  const TOKENS = BASE_TOKENS.slice().sort(
    (a, b) => b.token.length - a.token.length,
  );
  let remaining = fmt;
  let regexStr = "";
  let groups = [];

  while (remaining.length > 0) {
    const t = TOKENS.find(({ token }) => remaining.startsWith(token));
    if (t) {
      regexStr += t.regex;
      groups = [...groups, t.group];
      remaining = remaining.slice(t.token.length);
      continue;
    }

    regexStr += escapeRegexChar(remaining[0]);
    remaining = remaining.slice(1);
  }

  try {
    const re = new RegExp(`^${regexStr}$`, "i");
    return { re, groups };
  } catch (e) {
    return { re: null, groups: [] };
  }
};

/**
 * Escape a string or single character so it can be safely used in a regular expression.
 *
 * @param {string} ch - The input character or string to escape. Regex-special characters
 *                      such as . * + ? ^ $ { } ( ) | [ ] \ are escaped.
 * @returns {string} The input with regex-special characters escaped (prefixed with a backslash).
 *
 * @example
 * ```JavaScript
 * escapeRegexChar("."); // returns "\\."
 * escapeRegexChar("a*b"); // returns "a\\*b"
 * escapeRegexChar("normal"); // returns "normal"
 * ```
 */
const escapeRegexChar = (ch) => ch.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

/**
 * Create an object mapping capture group names to their corresponding values from a regex match array.
 *
 * @param {string[]} groups - Ordered list of capture group names (must align with the regex capture order).
 * @param {Array<string|undefined>} matchArray - Regex match array (e.g., result of RegExp#exec or String#match). Index 0 is the full match; capture groups start at index 1.
 * @returns {{[groupName: string]: string|undefined}} Object mapping each group name to the matched string or undefined if that capture was not present.
 *
 * @example
 * ```JavaScript
 * const groups = ["year", "month"];
 * const matchArray = ["2024-06", "2024", "06"];
 * mapMatchToGroups(groups, matchArray); // returns { year: "2024", month: "06" }
 * ```
 */
const mapMatchToGroups = (groups, matchArray) =>
  groups.reduce((acc, g, i) => ((acc[g] = matchArray[i + 1]), acc), {});

/**
 * Parses a value as a base-10 integer.
 *
 * Uses parseInt(value, 10). If the input is undefined or cannot be parsed to a valid integer (NaN),
 * the function returns undefined.
 *
 * @param {string|number|undefined} v - The value to parse as an integer.
 * @returns {number|undefined} The parsed integer (base 10), or undefined if input is undefined or not a valid integer.
 */
const parseNum = (v) => {
  if (v === undefined) return undefined;
  const n = parseInt(v, 10);
  return Number.isNaN(n) ? undefined : n;
};

/**
 * Convert a 12-hour clock value to a 24-hour integer.
 *
 * @param {string|number} v - Hour value in 12-hour form (e.g. "12", 1, "7"). This value is parsed via parseNum; if parsing fails, the function returns undefined.
 * @param {string} [ampm] - Optional meridiem indicator ("am" or "pm", case-insensitive). If "pm" (case-insensitive), 12 is added after normalizing the hour.
 * @returns {number|undefined} The hour in 24-hour format (0–23), or undefined if the input could not be parsed. Note: 12 AM becomes 0, and 12 PM becomes 12.
 */
const parseHour12 = (v, ampm) => {
  const n = parseNum(v);
  if (n === undefined) return undefined;
  let h = n % 12;
  if (ampm && ampm.toLowerCase() === "pm") h += 12;
  return h;
};

/**
 * Extracts normalized date and time components from a parsed-token map.
 *
 * Recognized input keys (case-sensitive):
 * - year4: 4-digit year
 * - year2: 2-digit year (00-49 -> 2000-2049, otherwise 1900-1999)
 * - monthFull / monthAbbr: textual month names (matched case-insensitively against MONTHS_FULL / MONTHS_ABBR)
 * - month2 / month1: numeric month (1-12)
 * - day2 / day1: numeric day
 * - hour24_2 / hour24_1: 24-hour hour
 * - hour12_2 / hour12_1 + ampm: 12-hour hour interpreted via parseHour12
 * - min2 / min1: minutes
 * - sec2 / sec1: seconds
 *
 * Defaults: year = 1970, month = 0 (January), day = 1, hour = 0, min = 0, sec = 0.
 * Numeric tokens are parsed with parseNum; textual months are matched to MONTHS_FULL / MONTHS_ABBR.
 * On any parse or match failure the function returns the result of invalidParts().
 *
 * @param {Object} vals - Map of parsed token values (strings or undefined).
 * @returns {{year:number, month:number, day:number, hour:number, min:number, sec:number}|*}
 *          Object with normalized date parts (month is zero-indexed 0-11). If parsing fails,
 *          returns whatever invalidParts() produces.
 */
const extractDateParts = (vals) => {
  let year = 1970;
  let month = 0;
  let day = 1;
  let hour = 0;
  let min = 0;
  let sec = 0;

  if (vals.year4) {
    const n = parseNum(vals.year4);
    if (n === undefined) return invalidParts();
    year = n;
  } else if (vals.year2) {
    const y2 = parseNum(vals.year2);
    if (y2 === undefined) return invalidParts();
    year = y2 <= 49 ? 2000 + y2 : 1900 + y2;
  }

  if (vals.monthFull) {
    const idx = MONTHS_FULL.indexOf(vals.monthFull.toLowerCase());
    if (idx === -1) return invalidParts();
    month = idx;
  } else if (vals.monthAbbr) {
    const idx = MONTHS_ABBR.indexOf(vals.monthAbbr.toLowerCase());
    if (idx === -1) return invalidParts();
    month = idx;
  } else if (vals.month2 !== undefined) {
    const n = parseNum(vals.month2);
    if (n === undefined) return invalidParts();
    month = n - 1;
  } else if (vals.month1 !== undefined) {
    const n = parseNum(vals.month1);
    if (n === undefined) return invalidParts();
    month = n - 1;
  }

  if (vals.day2 !== undefined) {
    const n = parseNum(vals.day2);
    if (n === undefined) return invalidParts();
    day = n;
  } else if (vals.day1 !== undefined) {
    const n = parseNum(vals.day1);
    if (n === undefined) return invalidParts();
    day = n;
  }

  if (vals.hour24_2 !== undefined) {
    const n = parseNum(vals.hour24_2);
    if (n === undefined) return invalidParts();
    hour = n;
  } else if (vals.hour24_1 !== undefined) {
    const n = parseNum(vals.hour24_1);
    if (n === undefined) return invalidParts();
    hour = n;
  } else if (vals.hour12_2 !== undefined) {
    const h = parseHour12(vals.hour12_2, vals.ampm);
    if (h === undefined) return invalidParts();
    hour = h;
  } else if (vals.hour12_1 !== undefined) {
    const h = parseHour12(vals.hour12_1, vals.ampm);
    if (h === undefined) return invalidParts();
    hour = h;
  }

  if (vals.min2 !== undefined) {
    const n = parseNum(vals.min2);
    if (n === undefined) return invalidParts();
    min = n;
  } else if (vals.min1 !== undefined) {
    const n = parseNum(vals.min1);
    if (n === undefined) return invalidParts();
    min = n;
  }

  if (vals.sec2 !== undefined) {
    const n = parseNum(vals.sec2);
    if (n === undefined) return invalidParts();
    sec = n;
  } else if (vals.sec1 !== undefined) {
    const n = parseNum(vals.sec1);
    if (n === undefined) return invalidParts();
    sec = n;
  }

  return { year, month, day, hour, min, sec };
};

/**
 * Returns a sentinel object representing invalid/default date parts used to indicate a parse failure.
 *
 * Properties:
 *  - year: NaN (invalid year)
 *  - month: 0
 *  - day: 1
 *  - hour: 0
 *  - min: 0
 *  - sec: 0
 *
 * @returns {{year: number, month: number, day: number, hour: number, min: number, sec: number}} Sentinel date parts
 */
const invalidParts = () => ({
  year: NaN,
  month: 0,
  day: 1,
  hour: 0,
  min: 0,
  sec: 0,
});

/**
 * Attempt to parse a date/time string according to the provided format and
 * return a UTC Date object, or undefined if parsing fails.
 *
 * Behavior summary:
 * - If `str` is falsy, returns undefined.
 * - Quick modes:
 *   - "ISO"         -> parsed by parseISO(str)
 *   - "epoch"       -> parsed as epoch seconds via parseEpochSeconds(str)
 *   - "epochMillis" -> parsed as epoch milliseconds via parseEpochMillis(str)
 * - If `fmt` is not a string (and not one of the quick modes), returns undefined.
 * - For custom format strings, a regex is built (via buildRegexFromFormat),
 *   the input is matched, groups are mapped and date parts extracted
 *   (year, month, day, hour, min, sec). A UTC Date is constructed and
 *   returned unless the resulting date is invalid, in which case undefined
 *   is returned.
 *
 * @param {string|undefined|null} str - The input date/time string to parse.
 * @param {string|undefined|null} fmt - A format identifier or custom format string.
 *                                       Supported quick values: "ISO", "epoch", "epochMillis".
 * @returns {Date|undefined} The parsed Date in UTC, or undefined if parsing failed or input invalid.
 *
 * @example
 * ```JavaScript
 * tryParseWithFormat("2024-06-01T12:34:56Z", "ISO"); // returns Date object for June 1, 2024 at 12:34:56 UTC
 * tryParseWithFormat("2024-06-01 12:34", "yyyy-MM-dd HH:mm"); // returns Date object for June 1, 2024 at 12:34 UTC
 * tryParseWithFormat("06/01/24", "MM/dd/yy"); // returns Date object for June 1, 2024
 * tryParseWithFormat("invalid", "ISO"); // returns undefined
 * tryParseWithFormat("2024-06-01T12:34:56Z", "unknownFormat"); // returns undefined
 * ```
 */
export default function tryParseWithFormat(str, fmt) {
  if (!str) return undefined;

  // quick modes
  if (fmt === "ISO") return parseISO(str);
  if (fmt === "epoch") return parseEpochSeconds(str);
  if (fmt === "epochMillis") return parseEpochMillis(str);
  if (typeof fmt !== "string") return undefined;

  const { re, groups } = buildRegexFromFormat(fmt);
  if (!re) return undefined;

  const m = str.match(re);
  if (!m) return undefined;

  const vals = mapMatchToGroups(groups, m);

  const { year, month, day, hour, min, sec } = extractDateParts(vals);

  const d = new Date(Date.UTC(year, month, day, hour, min, sec));
  return Number.isNaN(d.getTime()) ? undefined : d;
}
