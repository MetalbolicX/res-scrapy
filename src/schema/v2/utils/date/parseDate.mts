type TokenGroup =
  | "year4"
  | "year2"
  | "monthFull"
  | "monthAbbr"
  | "month2"
  | "month1"
  | "day2"
  | "day1"
  | "hour24_2"
  | "hour24_1"
  | "hour12_2"
  | "hour12_1"
  | "min2"
  | "min1"
  | "sec2"
  | "sec1"
  | "ampm";

interface BaseToken {
  token: string;
  regex: string;
  group: TokenGroup;
}

interface DateParts {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
}

interface TokenValues {
  [key: string]: string | undefined;
  year4?: string;
  year2?: string;
  monthFull?: string;
  monthAbbr?: string;
  month2?: string;
  month1?: string;
  day2?: string;
  day1?: string;
  hour24_2?: string;
  hour24_1?: string;
  hour12_2?: string;
  hour12_1?: string;
  min2?: string;
  min1?: string;
  sec2?: string;
  sec1?: string;
  ampm?: string;
}

interface RegexBuildResult {
  regex: RegExp | null;
  groupNames: TokenGroup[];
}

/**
 * Parses an ISO-8601 date string into a Date object.
 *
 * Attempts to construct a Date from the provided input string. If the input
 * cannot be parsed into a valid Date (i.e., results in NaN time), the function
 * returns undefined.
 *
 * @param input - The ISO-8601 date string to parse (e.g., "2023-03-14T15:09:26Z").
 * @returns A Date instance when parsing succeeds, or undefined for invalid input.
 * @example
 * ```TypeScript
 * const date1 = parseISO("2023-03-14T15:09:26Z");
 * console.log(date1); // Outputs: 2023-03-14T15:09:26.000Z
 * const date2 = parseISO("invalid-date");
 * console.log(date2); // Outputs: undefined
 * ```
 */
const parseISO = (input: string): Date | undefined => {
  const parsedDate = new Date(input);
  return Number.isNaN(parsedDate.getTime()) ? undefined : parsedDate;
};

/**
 * Parse an input representing epoch seconds and convert it to a Date.
 *
 * Accepts either a number or a string containing an integer/float representation
 * of epoch seconds (base 10). Numeric inputs are truncated toward zero; string
 * inputs are parsed with base 10. The value is converted to milliseconds and
 * used to construct a Date object.
 *
 * @param secondsInput - Epoch seconds as a number or numeric string.
 * @returns A Date corresponding to the given epoch seconds, or `undefined` if
 *          the input is not a valid numeric representation or results in an
 *          invalid Date.
 *
 * @remarks
 * - Floats are truncated (e.g., 1.9 -> 1).
 * - Strings are parsed with radix 10.
 * - Negative values (seconds before 1970-01-01T00:00:00Z) are supported.
 *
 * @example
 * ```TypeScript
 * const date1 = parseEpochSeconds(1678900000);
 * console.log(date1); // Outputs: 2023-03-15T00:13:20.000Z
 * const date2 = parseEpochSeconds("1678900000");
 * console.log(date2); // Outputs: 2023-03-15T00:13:20.000Z
 * const date3 = parseEpochSeconds("invalid");
 * console.log(date3); // Outputs: undefined
 * const date4 = parseEpochSeconds(1.9);
 * console.log(date4); // Outputs: 1970-01-01T00:00:01.000Z
 * const date5 = parseEpochSeconds(-1);
 * console.log(date5); // Outputs: 1969-12-31T23:59:59.000Z
 * ```
 */
const parseEpochSeconds = (secondsInput: string | number): Date | undefined => {
  const seconds =
    typeof secondsInput === "number"
      ? Math.trunc(secondsInput)
      : parseInt(String(secondsInput), 10);
  if (Number.isNaN(seconds)) return undefined;
  const milliseconds = seconds * 1000;
  const parsedDate = new Date(milliseconds);
  return Number.isNaN(parsedDate.getTime()) ? undefined : parsedDate;
};

/**
 * Parse an epoch millisecond value into a Date.
 *
 * Accepts a `number` or `string`. If a number is provided it will be truncated
 * to an integer. If a string is provided it will be parsed with `parseInt(..., 10)`.
 * If the parsed millisecond value is `NaN` or produces an invalid `Date`, the function
 * returns `undefined`.
 *
 * @param millisInput - Epoch milliseconds as a `number` or numeric `string`.
 * @returns The corresponding `Date`, or `undefined` if parsing or date construction fails.
 *
 * @example
 * ```TypeScript
 * const date1 = parseEpochMillis(1678900000000);
 * console.log(date1); // Outputs: 2023-03-15T00:13:20.000Z
 * const date2 = parseEpochMillis("1678900000000");
 * console.log(date2); // Outputs: 2023-03-15T00:13:20.000Z
 * const date3 = parseEpochMillis("invalid");
 * console.log(date3); // Outputs: undefined
 * const date4 = parseEpochMillis(1678900000000.9);
 * console.log(date4); // Outputs: 2023-03-15T00:13:20.000Z
 * const date5 = parseEpochMillis(-1000);
 * console.log(date5); // Outputs: 1969-12-31T23:59:59.000Z
 * ```
 */
const parseEpochMilliseconds = (
  millisInput: string | number,
): Date | undefined => {
  const milliseconds =
    typeof millisInput === "number"
      ? Math.trunc(millisInput)
      : parseInt(String(millisInput), 10);
  if (Number.isNaN(milliseconds)) return undefined;
  const parsedDate = new Date(milliseconds);
  return Number.isNaN(parsedDate.getTime()) ? undefined : parsedDate;
};

/**
 * Parse an epoch timestamp expressed in milliseconds into a Date instance.
 *
 * Accepts either a number (milliseconds since Unix epoch) or a numeric string.
 * Returns a Date representing that instant, or `undefined` when the input is
 * not a finite numeric value or cannot be converted to a valid Date.
 *
 * @param millisInput - Epoch milliseconds as a number or numeric string.
 * @returns A Date for the given epoch milliseconds, or `undefined` if the input is invalid.
 *
 * @example
 * ```TypeScript
 * const date1 = parseEpochMillis(1678900000000);
 * console.log(date1); // Outputs: 2023-03-15T00:13:20.000Z
 * const date2 = parseEpochMillis("1678900000000");
 * console.log(date2); // Outputs: 2023-03-15T00:13:20.000Z
 * const date3 = parseEpochMillis("invalid");
 * console.log(date3); // Outputs: undefined
 * const date4 = parseEpochMillis(1678900000000.9);
 * console.log(date4); // Outputs: 2023-03-15T00:13:20.000Z
 * const date5 = parseEpochMillis(-1000);
 * console.log(date5); // Outputs: 1969-12-31T23:59:59.000Z
 * ```
 *
 * @remarks
 * This is a thin wrapper that delegates parsing to parseEpochMilliseconds.
 */
const parseEpochMillis = (millisInput: string | number): Date | undefined =>
  parseEpochMilliseconds(millisInput);

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

const BASE_TOKENS: BaseToken[] = [
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

/**
 * Build a regular expression and a corresponding list of token groups from a
 * date format string.
 *
 * The function scans the provided `format` from left to right and attempts to
 * consume the longest matching tokens defined in `BASE_TOKENS`. For each matched
 * token it appends the token's `regex` fragment to the overall pattern and
 * records the token's `group` in `groupNames`. Characters that do not match any
 * token are treated as literal text and are escaped before being appended to
 * the pattern.
 *
 * The resulting pattern is wrapped with anchors (`^...$`) and compiled with
 * the case-insensitive flag (`i`). If compilation fails, the function returns
 * an object with `regex: null` and an empty `groupNames` array.
 *
 * Notes:
 * - Tokens are matched using a longest-first strategy to avoid partial token
 *   collisions (e.g. "YYYY" before "YY").
 * - Literal characters do not produce capturing groups; `groupNames` only
 *   contains entries for matched tokens in the order they appear in the final
 *   regular expression. The ordering of `groupNames` corresponds to the order
 *   of capturing groups produced by concatenating the token regex fragments.
 *
 * @param format - A format string composed of token identifiers (from
 *   BASE_TOKENS) mixed with literal characters.
 * @returns An object with:
 *   - `regex`: the compiled RegExp instance (or `null` if compilation failed).
 *   - `groupNames`: an array of token group identifiers (TokenGroup) in the
 *     same order as the regex's capturing groups.
 *
 * @example
 * ```TypeScript
 * const { regex, groupNames } = buildRegexFromFormat("yyyy-MM-dd HH:mm:ss");
 * console.log(regex); // Outputs: /^\d{4}-(\d{1,2})-(\d{1,2}) (\d{1,2}):(\d{1,2}):(\d{1,2})$/i
 * console.log(groupNames); // Outputs: ["year4", "month2", "day2", "hour24_2", "min2", "sec2"]
 * ```
 *
 * @remarks
 * This function is a core part of the date parsing logic that allows flexible
 * date formats to be defined and parsed without hardcoding specific patterns.
 */
const buildRegexFromFormat = (format: string): RegexBuildResult => {
  const sortedTokens = BASE_TOKENS.slice().sort(
    (a, b) => b.token.length - a.token.length,
  );

  let remaining = format;
  let pattern = "";
  const groupNames: TokenGroup[] = [];

  while (remaining.length > 0) {
    const matchedToken = sortedTokens.find(({ token }) =>
      remaining.startsWith(token),
    );
    if (matchedToken) {
      pattern += matchedToken.regex;
      groupNames.push(matchedToken.group);
      remaining = remaining.slice(matchedToken.token.length);
      continue;
    }

    pattern += escapeRegexCharacter(remaining[0]);
    remaining = remaining.slice(1);
  }

  try {
    const compiledRegex = new RegExp(`^${pattern}$`, "i");
    return { regex: compiledRegex, groupNames };
  } catch {
    return { regex: null, groupNames: [] };
  }
};

/**
 * Escapes all special characters in a string that have meaning in regular expressions,
 * allowing the string to be used literally in a RegExp pattern.
 *
 * @param text - The input string that may contain RegExp metacharacters.
 * @returns A new string with RegExp-special characters escaped (prefixed with a backslash).
 *
 * @example
 * ```TypeScript
 * const escaped = escapeRegexCharacter("2023-03-14T15:09:26Z");
 * console.log(escaped); // Outputs: "2023\-03\-14T15\:09\:26Z"
 * ```
 */
const escapeRegexCharacter = (text: string): string =>
  text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

/**
 * Map regex capture group names to their corresponding match values.
 *
 * Given an ordered list of capture group names and the array of matches
 * produced by `RegExp.prototype.exec` (or a similar source), returns an
 * object that associates each group name with the matched string for that
 * group (or `undefined` if the group did not participate in the match).
 *
 * @param groupNames - Ordered array of capture group names.
 * @param matches - Match array where index 0 is the full match and subsequent
 *                  indices correspond to capture groups.
 * @returns An object mapping each group name to its match value (`string`)
 *          or `undefined` if no value exists for that group.
 *
 * @remarks
 * The function uses a 1-based offset into `matches` (i.e., `matches[i + 1]`)
 * because `matches[0]` contains the full match. If `matches` is shorter than
 * `groupNames`, outstanding group names will be mapped to `undefined`.
 *
 * @example
 * ```ts
 * const groupNames = ['year', 'month', 'day'];
 * const matches = ['2023-03-14', '2023', '03', '14'];
 * const result = mapMatchToGroupValues(groupNames, matches);
 * console.log(result); // Outputs: { year: '2023', month: '03', day: '14' }
 * ```
 */
const mapMatchToGroupValues = (
  groupNames: readonly string[],
  matches: Array<string | undefined>,
): Record<string, string | undefined> =>
  groupNames.reduce<Record<string, string | undefined>>(
    (mapper, groupName, i) => {
      mapper[groupName] = matches[i + 1];
      return mapper;
    },
    {},
  );

/**
 * Parse a value as an integer using base 10.
 *
 * Converts a string or number input to an integer using parseInt(..., 10).
 * - If the input is `undefined`, returns `undefined`.
 * - If the input cannot be parsed into a valid integer, returns `undefined`.
 * - Non-digit trailing characters in strings are ignored (e.g. "42px" -> 42).
 * - Decimal values are truncated (e.g. "3.14" -> 3).
 *
 * @param rawNumber - The value to parse (string | number | undefined).
 * @returns The parsed integer, or `undefined` if the input is `undefined` or not a valid integer.
 *
 * @example
 * ```TypeScript
 * console.log(parseInteger("42")); // Outputs: 42
 * console.log(parseInteger(3.14)); // Outputs: 3
 * console.log(parseInteger("invalid")); // Outputs: undefined
 * console.log(parseInteger(undefined)); // Outputs: undefined
 * console.log(parseInteger("42px")); // Outputs: 42
 * ```
 */
const parseInteger = (
  rawNumber: string | number | undefined,
): number | undefined => {
  if (rawNumber === undefined) return undefined;
  const n = parseInt(String(rawNumber), 10);
  return Number.isNaN(n) ? undefined : n;
};

/**
 * Converts a 12-hour clock hour value to its 24-hour equivalent.
 *
 * Parses a numeric hour from a string or number, normalizes 12 to 0 before applying the
 * meridiem adjustment, and returns a value in the range 0–23. The meridiem check is
 * case-insensitive and only "pm" will cause a +12 adjustment.
 *
 * @param hourValue - Hour expressed as a number or numeric string (e.g. 1, "01", "12").
 * @param meridiem - Optional meridiem indicator ("am" or "pm", case-insensitive). If omitted,
 *                   the hour is treated as AM (no +12 adjustment).
 * @returns The hour in 24-hour format (0–23), or undefined if the input cannot be parsed.
 */
const convert12HourTo24 = (
  hourValue: string | number,
  meridiem?: string,
): number | undefined => {
  const num = parseInteger(hourValue);
  if (num === undefined) return undefined;
  let hour = num % 12;
  if (meridiem && meridiem.toLowerCase() === "pm") hour += 12;
  return hour;
};

/**
 * Normalize a set of tokenized date/time values into canonical DateParts.
 *
 * The function examines the provided token values in a defined precedence order,
 * parses numeric tokens, converts 12-hour times using an AM/PM marker, and fills
 * missing components with sensible defaults.
 *
 * Precedence and conversion rules:
 * - Year: `year4` (4-digit) preferred; otherwise `year2` (2-digit) is interpreted
 *   as: <= 49 => 2000 + year2, else 1900 + year2.
 * - Month: prefer `monthFull` (case-insensitive full month name), then
 *   `monthAbbr` (case-insensitive abbreviated name), then numeric `month2`,
 *   then numeric `month1`. Numeric months are parsed as 1-based and converted
 *   to 0-based for the returned parts.
 * - Day: prefer `day2` then `day1` (both parsed as integers).
 * - Hour: prefer 24-hour tokens (`hour24_2`, then `hour24_1`); if absent,
 *   prefer 12-hour tokens (`hour12_2`, then `hour12_1`) and convert to 24-hour
 *   using `ampm`. If AM/PM is missing or conversion fails, the result is invalid.
 * - Minute: prefer `min2` then `min1`.
 * - Second: prefer `sec2` then `sec1`.
 *
 * Defaults:
 * - If a component is entirely absent, defaults are used: year = 1970,
 *   month = 0 (January), day = 1, hour = 0, minute = 0, second = 0.
 *
 * Error handling:
 * - Numeric token parsing failures, unknown month names, or invalid 12-hour
 *   conversions cause the function to return the sentinel value produced by
 *   `invalidDateParts()` to indicate a parse failure.
 *
 * @param tokenValues - An object containing optional parsed tokens (strings)
 *   such as year4, year2, monthFull, monthAbbr, month2, month1, day2, day1,
 *   hour24_2, hour24_1, hour12_2, hour12_1, ampm, min2, min1, sec2, sec1.
 * @returns A DateParts object: { year, month, day, hour, minute, second } where
 *   month is 0-based. Returns the `invalidDateParts()` sentinel on parse errors.
 */
const normalizeDateParts = (tokenValues: TokenValues): DateParts => {
  let year = 1970;
  let month = 0;
  let day = 1;
  let hour = 0;
  let minute = 0;
  let second = 0;

  if (tokenValues.year4) {
    const n = parseInteger(tokenValues.year4);
    if (n === undefined) return invalidDateParts();
    year = n;
  } else if (tokenValues.year2) {
    const y2 = parseInteger(tokenValues.year2);
    if (y2 === undefined) return invalidDateParts();
    year = y2 <= 49 ? 2000 + y2 : 1900 + y2;
  }

  if (tokenValues.monthFull) {
    const idx = MONTHS_FULL.indexOf(tokenValues.monthFull.toLowerCase());
    if (idx === -1) return invalidDateParts();
    month = idx;
  } else if (tokenValues.monthAbbr) {
    const idx = MONTHS_ABBR.indexOf(tokenValues.monthAbbr.toLowerCase());
    if (idx === -1) return invalidDateParts();
    month = idx;
  } else if (tokenValues.month2 !== undefined) {
    const n = parseInteger(tokenValues.month2);
    if (n === undefined) return invalidDateParts();
    month = n - 1;
  } else if (tokenValues.month1 !== undefined) {
    const n = parseInteger(tokenValues.month1);
    if (n === undefined) return invalidDateParts();
    month = n - 1;
  }

  if (tokenValues.day2 !== undefined) {
    const n = parseInteger(tokenValues.day2);
    if (n === undefined) return invalidDateParts();
    day = n;
  } else if (tokenValues.day1 !== undefined) {
    const n = parseInteger(tokenValues.day1);
    if (n === undefined) return invalidDateParts();
    day = n;
  }

  if (tokenValues.hour24_2 !== undefined) {
    const n = parseInteger(tokenValues.hour24_2);
    if (n === undefined) return invalidDateParts();
    hour = n;
  } else if (tokenValues.hour24_1 !== undefined) {
    const n = parseInteger(tokenValues.hour24_1);
    if (n === undefined) return invalidDateParts();
    hour = n;
  } else if (tokenValues.hour12_2 !== undefined) {
    const h = convert12HourTo24(tokenValues.hour12_2, tokenValues.ampm);
    if (h === undefined) return invalidDateParts();
    hour = h;
  } else if (tokenValues.hour12_1 !== undefined) {
    const h = convert12HourTo24(tokenValues.hour12_1, tokenValues.ampm);
    if (h === undefined) return invalidDateParts();
    hour = h;
  }

  if (tokenValues.min2 !== undefined) {
    const n = parseInteger(tokenValues.min2);
    if (n === undefined) return invalidDateParts();
    minute = n;
  } else if (tokenValues.min1 !== undefined) {
    const n = parseInteger(tokenValues.min1);
    if (n === undefined) return invalidDateParts();
    minute = n;
  }

  if (tokenValues.sec2 !== undefined) {
    const n = parseInteger(tokenValues.sec2);
    if (n === undefined) return invalidDateParts();
    second = n;
  } else if (tokenValues.sec1 !== undefined) {
    const n = parseInteger(tokenValues.sec1);
    if (n === undefined) return invalidDateParts();
    second = n;
  }

  return { year, month, day, hour, minute, second };
};

/**
 * Create a sentinel DateParts object that represents an invalid or uninitialized date.
 *
 * The sentinel values are chosen so callers can reliably detect parsing failures:
 * - year: NaN to indicate "not a number" / invalid year
 * - month: 0 (invalid, as valid months are 1–12)
 * - day: 1 (neutral/default day)
 * - hour: 0, minute: 0, second: 0 (zeroed time components)
 *
 * @returns A DateParts object that signals an invalid date.
 */
const invalidDateParts = (): DateParts => ({
  year: Number.NaN,
  month: 0,
  day: 1,
  hour: 0,
  minute: 0,
  second: 0,
});

/**
 * Attempt to parse a date-time string using a provided format and return a Date (UTC) or undefined.
 *
 * Supports the following special format identifiers:
 * - "ISO" — parse as ISO 8601
 * - "epoch" — parse as seconds since Unix epoch
 * - "epochMillis" — parse as milliseconds since Unix epoch
 *
 * For other string formats, a regex is constructed from the format (via buildRegexFromFormat),
 * the input is matched, named capture groups are mapped to values (via mapMatchToGroupValues),
 * and the parts are normalized into year, month, day, hour, minute, and second (via normalizeDateParts).
 * The resulting Date is created with Date.UTC(...), so it represents the parsed time in UTC.
 *
 * Returns undefined for null/empty inputs, non-string formats, regex/build or match failures,
 * or when the constructed Date is invalid.
 *
 * @param datetime - The date-time string to parse (may be null or undefined).
 * @param format - The format specifier string, or null/undefined. Special values: "ISO", "epoch", "epochMillis".
 * @returns The parsed Date in UTC, or undefined if parsing fails.
 */
export default function tryParseWithFormat(
  datetime: string | null | undefined,
  format: string | null | undefined,
): Date | undefined {
  if (!datetime) return undefined;

  if (format === "ISO") return parseISO(datetime);
  if (format === "epoch") return parseEpochSeconds(datetime);
  if (format === "epochMillis") return parseEpochMillis(datetime);
  if (typeof format !== "string") return undefined;

  const { regex, groupNames } = buildRegexFromFormat(format);
  if (!regex) return undefined;

  const matchResult = datetime.match(regex);
  if (!matchResult) return undefined;

  const tokenMap = mapMatchToGroupValues(groupNames, matchResult);
  const { year, month, day, hour, minute, second } =
    normalizeDateParts(tokenMap);

  const resultDate = new Date(Date.UTC(year, month, day, hour, minute, second));
  return Number.isNaN(resultDate.getTime()) ? undefined : resultDate;
}
