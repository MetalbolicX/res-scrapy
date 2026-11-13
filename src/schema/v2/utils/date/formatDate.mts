interface DateComponents {
  year: number;
  month: number;
  day: number;
  hour: number;
  min: number;
  sec: number;
  offset: number;
}

interface TokenDefinition {
  token: string;
  value: string;
}

const MONTHS_FULL = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
];

const MONTHS_ABBR = [
  "Jan",
  "Feb",
  "Mar",
  "Apr",
  "May",
  "Jun",
  "Jul",
  "Aug",
  "Sep",
  "Oct",
  "Nov",
  "Dec",
];

/**
 * Pads a number or string to at least two characters by prepending a "0" when necessary.
 *
 * The input is converted to a string before padding. If the resulting string has a length
 * of two or more characters it is returned unchanged.
 *
 * @param value - The number or string to format.
 * @returns The input converted to a string and left-padded with "0" to a minimum length of 2.
 *
 * @example
 * ```TypeScript
 * console.log(padToTwoDigits(5)); // Outputs: "05"
 * console.log(padToTwoDigits("9")); // Outputs: "09"
 * console.log(padToTwoDigits(12)); // Outputs: "12"
 * console.log(padToTwoDigits("123")); // Outputs: "123"
 * ```
 *
 * @remarks
 * This function is used to ensure that date components like months, days, hours, minutes, and seconds
 * are consistently represented with at least two digits in formatted date strings.
 */
const padToTwoDigits = (value: number | string): string =>
  String(value).padStart(2, "0");

/**
 * Pads the given value with leading zeros so the resulting string is at least 4 characters long.
 *
 * The input is converted to a string and left-padded with `'0'` characters until its length is
 * at least 4. Values longer than 4 characters are returned unchanged.
 *
 * Note: negative numbers retain the `-` sign and zeros may appear before it (e.g. `-12` -> `"0-12"`).
 *
 * @param value - The number or string to convert and pad.
 * @returns The padded string representation of the input, with a minimum length of 4.
 *
 * @example
 * ```TypeScript
 * console.log(padToFourDigits(5)); // Outputs: "0005"
 * console.log(padToFourDigits("9")); // Outputs: "0009"
 * console.log(padToFourDigits(12)); // Outputs: "0012"
 * console.log(padToFourDigits("123")); // Outputs: "0123"
 * console.log(padToFourDigits(1234)); // Outputs: "1234"
 * console.log(padToFourDigits("12345")); // Outputs: "12345"
 * console.log(padToFourDigits(-12)); // Outputs: "0-12"
 * ```
 *
 * @remarks
 * This function is primarily used for formatting the year component of dates, ensuring that it is
 * represented with at least four digits in formatted date strings.
 */
const padToFourDigits = (value: number | string): string =>
  String(value).padStart(4, "0");

/**
 * Resolves the calendar components of an instant in an IANA time zone.
 *
 * `toZonedDateTimeISO` handles DST and historical offsets directly, so no
 * locale formatting or offset-string parsing is needed. Offsets with a seconds
 * part (e.g. the 1874 New York LMT offset -04:56:02) are truncated to whole
 * minutes to match the `±HH:MM` output.
 *
 * @param instant - The instant to resolve.
 * @param timeZone - An IANA time zone identifier (e.g. "UTC", "America/New_York").
 * @returns The DateComponents with a zero-based month and the offset in minutes.
 * @throws RangeError when `timeZone` is not a valid time zone identifier.
 */
const getDateComponents = (
  instant: Temporal.Instant,
  timeZone: string,
): DateComponents => {
  const zoned = instant.toZonedDateTimeISO(timeZone);
  return {
    year: zoned.year,
    month: zoned.month - 1,
    day: zoned.day,
    hour: zoned.hour,
    min: zoned.minute,
    sec: zoned.second,
    offset: Math.trunc(zoned.offsetNanoseconds / 60_000_000_000),
  };
};

/**
 * Formats a time zone offset, given in minutes, into an ISO 8601 time zone designator.
 *
 * - Returns "Z" when the offset is 0.
 * - Returns a string in the form "+HH:MM" or "-HH:MM" for nonzero offsets.
 *
 * @param offsetMinutes - The time zone offset in minutes. Positive values yield a "+" sign; negative values yield a "-" sign.
 * @returns A string representing the time zone offset ("Z" or "+HH:MM"/"-HH:MM").
 *
 * @example
 * ```TypeScript
 * console.log(formatTimeZoneOffset(0)); // Outputs: "Z"
 * console.log(formatTimeZoneOffset(120)); // Outputs: "+02:00"
 * console.log(formatTimeZoneOffset(-330)); // Outputs: "-05:30"
 * console.log(formatTimeZoneOffset(15)); // Outputs: "+00:15"
 * console.log(formatTimeZoneOffset(-45)); // Outputs: "-00:45"
 * ```
 *
 * @remarks
 * This function is used to convert a numeric time zone offset into a standardized string format suitable for ISO 8601 date representations.
 */
const formatTimeZoneOffset = (offsetMinutes: number): string => {
  if (offsetMinutes === 0) return "Z";
  const sign = offsetMinutes > 0 ? "+" : "-";
  const absoluteOffset = Math.abs(offsetMinutes);
  return `${sign}${padToTwoDigits(Math.floor(absoluteOffset / 60))}:${padToTwoDigits(
    absoluteOffset % 60,
  )}`;
};

/**
 * Creates a list of TokenDefinition objects that map date/time format tokens to
 * their computed string values based on the supplied DateComponents.
 *
 * Supported tokens and their meanings:
 * - "yyyy": four-digit year (padded)
 * - "yy": last two digits of the year (padded)
 * - "MMMM": full month name (from MONTHS_FULL)
 * - "MMM": abbreviated month name (from MONTHS_ABBR)
 * - "MM": two-digit month (01-12; computed from components.month + 1)
 * - "M": numeric month without padding (1-12)
 * - "dd": two-digit day of month (padded)
 * - "d": day of month without padding
 * - "HH": two-digit 24-hour (00-23)
 * - "H": 24-hour without padding
 * - "hh": two-digit 12-hour (01-12; uses hour % 12 || 12)
 * - "h": 12-hour without padding
 * - "mm": two-digit minutes (padded)
 * - "m": minutes without padding
 * - "ss": two-digit seconds (padded)
 * - "s": seconds without padding
 * - "a": meridiem indicator ("am" | "pm")
 *
 * @param components - DateComponents used to derive token values.
 *   Expected shape (typical): { year: number, month: number, day: number, hour: number, min: number, sec: number }.
 *   Note: month is zero-based (0 = January) as values for "MM"/"M" are computed via month + 1.
 *
 * @returns An array of TokenDefinition objects ({ token: string, value: string }) for each supported token.
 *
 * @remarks
 * - Padding helpers (padToTwoDigits, padToFourDigits) are used where appropriate.
 * - 12-hour tokens use (hour % 12 || 12) so midnight/noon are represented as "12".
 */
const createTokenDefinitions = (
  components: DateComponents,
): TokenDefinition[] => [
  { token: "yyyy", value: padToFourDigits(components.year) },
  { token: "yy", value: padToTwoDigits(components.year % 100) },
  { token: "MMMM", value: MONTHS_FULL[components.month] },
  { token: "MMM", value: MONTHS_ABBR[components.month] },
  { token: "MM", value: padToTwoDigits(components.month + 1) },
  { token: "M", value: String(components.month + 1) },
  { token: "dd", value: padToTwoDigits(components.day) },
  { token: "d", value: String(components.day) },
  { token: "HH", value: padToTwoDigits(components.hour) },
  { token: "H", value: String(components.hour) },
  { token: "hh", value: padToTwoDigits(components.hour % 12 || 12) },
  { token: "h", value: String(components.hour % 12 || 12) },
  { token: "mm", value: padToTwoDigits(components.min) },
  { token: "m", value: String(components.min) },
  { token: "ss", value: padToTwoDigits(components.sec) },
  { token: "s", value: String(components.sec) },
  { token: "a", value: components.hour < 12 ? "am" : "pm" },
];

/**
 * Format a Temporal.Instant into a string according to one of several built-in formats or a custom token-based format.
 *
 * Supported special outputFormat values:
 * - "epoch"       - seconds since Unix epoch (rounded down) as a string
 * - "epochMillis" - milliseconds since Unix epoch as a string
 * - "iso8601"     - ISO 8601 timestamp with zero-padded components and timezone offset
 *
 * For any other outputFormat value a token substitution mechanism is used: token definitions are created
 * from the date components (year, month, day, hour, minute, second, offset, etc.) and the function
 * replaces tokens in the provided format string with their corresponding values. Characters that do not
 * match a token are copied verbatim.
 *
 * Notes:
 * - If timeZone is not provided, "UTC" is used.
 * - If outputFormat is omitted or an empty string is passed, the function returns an empty string.
 *
 * @param instant - The instant to format.
 * @param outputFormat - Optional format specifier ("epoch", "epochMillis", "iso8601", or a custom token format).
 * @param timeZone - Optional IANA time zone identifier (defaults to "UTC") used to compute date components.
 * @returns The formatted date as a string according to the requested format.
 *
 * @example
 * ```TypeScript
 * const date = Temporal.Instant.from("2024-01-02T15:04:05Z");
 * console.log(formatDate(date, "epoch")); // Outputs: "1704207845"
 * console.log(formatDate(date, "epochMillis")); // Outputs: "1704207845000"
 * console.log(formatDate(date, "iso8601")); // Outputs: "2024-01-02T15:04:05Z"
 * console.log(formatDate(date, "yyyy/MM/dd HH:mm:ss")); // Outputs: "2024/01/02 15:04:05"
 * console.log(formatDate(date, "MMM d, yyyy h:mm a", "America/New_York")); // Outputs: "Jan 2, 2024 10:04 am"
 * ```
 *
 * @remarks
 * - The token-based formatting allows for flexible date string construction without hardcoding specific formats.
 * - Time zone handling ensures that the formatted output can reflect the correct local time for a given IANA time zone, or UTC if none is specified.
 */
export default function formatDate(
  instant: Temporal.Instant,
  outputFormat?: string,
  timeZone?: string,
): string {
  if (outputFormat === "epoch")
    return String(Math.floor(instant.epochMilliseconds / 1000));
  if (outputFormat === "epochMillis") return String(instant.epochMilliseconds);

  const components = getDateComponents(instant, timeZone || "UTC");

  if (outputFormat === "iso8601") {
    return `${padToFourDigits(components.year)}-${padToTwoDigits(components.month + 1)}-${padToTwoDigits(components.day)}T${padToTwoDigits(components.hour)}:${padToTwoDigits(components.min)}:${padToTwoDigits(components.sec)}${formatTimeZoneOffset(components.offset)}`;
  }

  const tokenDefinitions = createTokenDefinitions(components);

  let formattedOutput = "";
  let remainingFormat = outputFormat || "";

  while (remainingFormat.length > 0) {
    let matched = false;
    for (const tokenDefinition of tokenDefinitions) {
      if (remainingFormat.startsWith(tokenDefinition.token)) {
        formattedOutput += tokenDefinition.value;
        remainingFormat = remainingFormat.slice(tokenDefinition.token.length);
        matched = true;
        break;
      }
    }
    if (!matched) {
      formattedOutput += remainingFormat[0];
      remainingFormat = remainingFormat.slice(1);
    }
  }

  return formattedOutput;
}
