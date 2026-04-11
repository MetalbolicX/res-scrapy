"use strict";

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
 * Return a two-character string for the given value, padding with a leading zero if necessary.
 *
 * @param {number|string} value - The value to format.
 * @returns {string} The value converted to a string and left-padded with '0' to at least two characters.
 */
const padToTwoDigits = (value) => String(value).padStart(2, "0");
/**
 * Pads a value to at least four characters with leading zeros.
 *
 * @param {number|string} value - The value to pad; will be converted to a string.
 * @returns {string} The input as a string left-padded with zeros to a minimum length of 4.
 */
const padToFourDigits = (value) => String(value).padStart(4, "0");

/**
 * Parses a timezone name in the "GMT±HH" or "GMT±HH:MM" form and returns the offset in minutes.
 *
 * The function accepts strings like "GMT+2", "GMT-05", or "GMT+05:30". If the minutes portion is
 * omitted it is treated as zero. The parsing is case-sensitive and expects the literal "GMT" prefix.
 * If the input is falsy or does not match the expected pattern, the function returns 0.
 *
 * @param {string} [timeZoneName] - Time zone string in the form "GMT±HH" or "GMT±HH:MM".
 * @returns {number} Offset from GMT in minutes. Positive for offsets east of GMT (e.g. "GMT+2" -> 120),
 *                   negative for offsets west of GMT (e.g. "GMT-05:30" -> -330). Returns 0 for invalid or missing input.
 *
 * @example
 * ```JavaScript
 * parseTimeZoneOffsetMinutes('GMT+2');       // returns 120
 * parseTimeZoneOffsetMinutes('GMT-05:30');   // returns -330
 * parseTimeZoneOffsetMinutes(null);          // returns 0
 * ```
 */
const parseTimeZoneOffsetMinutes = (timeZoneName) => {
  if (!timeZoneName) return 0;
  const match = timeZoneName.match(/GMT([+-])(\d+)(?::(\d+))?/);
  if (!match) return 0;
  const sign = match[1] === "+" ? 1 : -1;
  const hours = parseInt(match[2], 10) || 0;
  const minutes = parseInt(match[3] || "0", 10);
  return sign * (hours * 60 + minutes);
};

/**
 * Extract UTC date/time components from a Date object.
 *
 * @param {Date} date - The Date instance to read UTC values from.
 * @returns {{year: number, month: number, day: number, hour: number, min: number, sec: number, offset: number}}
 *   An object containing:
 *   - year: full UTC year (e.g., 2026)
 *   - month: zero-based UTC month index (0 = January, 11 = December)
 *   - day: UTC day of month (1-31)
 *   - hour: UTC hour (0-23)
 *   - min: UTC minutes (0-59)
 *   - sec: UTC seconds (0-59)
 *   - offset: timezone offset in hours relative to UTC (always 0 for UTC components)
 */
const getUtcDateComponents = (date) => ({
  year: date.getUTCFullYear(),
  month: date.getUTCMonth(),
  day: date.getUTCDate(),
  hour: date.getUTCHours(),
  min: date.getUTCMinutes(),
  sec: date.getUTCSeconds(),
  offset: 0,
});

/**
 * Get numeric date/time components for a Date in a specific IANA timezone.
 *
 * @param {Date} date - The Date instance to format.
 * @param {string} timeZone - IANA timezone identifier (e.g. "America/New_York").
 * @returns {{
 *   year: number,
 *   month: number, // zero-based (0 = January)
 *   day: number,
 *   hour: number,  // 0-23 (a formatted "24" is normalized to 0)
 *   min: number,
 *   sec: number,
 *   offset: number // timezone offset as returned by parseOffsetFromTimeZoneName (minutes east of UTC)
 * }}
 *
 * @example
 * ```JavaScript
 * const date = new Date('2024-06-01T12:00:00Z');
 * getTimeZoneDateComponents(date, 'America/New_York');
 * // Might return:
 * // {
 * //   year: 2024,
 * //   month: 5, // June (0-based)
 * //   day: 1,
 * //   hour: 8, // 12:00 UTC is 08:00 in New York during daylight saving time
 * //   min: 0,
 * //   sec: 0,
 * //   offset: -240 // New York is UTC-4 during daylight saving time
 * // }
 * ```
 */
const getTimeZoneDateComponents = (date, timeZone) => {
  const dateTimeFormatter = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
    timeZoneName: "shortOffset",
  });

  const dateParts = Object.fromEntries(
    dateTimeFormatter
      .formatToParts(date)
      .map(({ type, value }) => [type, value]),
  );

  let hour = parseInt(dateParts.hour, 10);
  if (hour === 24) hour = 0;

  return {
    year: parseInt(dateParts.year, 10),
    month: parseInt(dateParts.month, 10) - 1,
    day: parseInt(dateParts.day, 10),
    hour,
    min: parseInt(dateParts.minute, 10),
    sec: parseInt(dateParts.second, 10),
    offset: parseTimeZoneOffsetMinutes(dateParts.timeZoneName || ""),
  };
};

/**
 * Get date/time components for a given Date either in UTC or a specified timezone.
 *
 * @param {Date} date - The Date object to extract components from.
 * @param {string} [timeZone] - Optional IANA timezone identifier. If omitted or equal to "UTC", UTC components are returned.
 * @returns {Object} An object containing individual date/time components (e.g. year, month, day, hour, minute, second, millisecond). The exact shape may vary depending on whether UTC or timezone-specific helpers are used.
 */
const getDateComponents = (date, timeZone) =>
  !timeZone || timeZone === "UTC"
    ? getUtcDateComponents(date)
    : getTimeZoneDateComponents(date, timeZone);

/**
 * Convert a timezone offset in minutes to an RFC-3339 style timezone string.
 *
 * @param {number} offsetMin - Offset from UTC in minutes. Positive values indicate
 *                             timezones ahead of UTC.
 * @returns {string} "Z" for zero offset, otherwise a string in the form "+HH:MM" or "-HH:MM".
 * @example
 * ```JavaScript
 * formatTimeZoneOffset(0);    // returns "Z"
 * formatTimeZoneOffset(120);  // returns "+02:00"
 * formatTimeZoneOffset(-330); // returns "-05:30"
 * ```
 */
const formatTimeZoneOffset = (offsetMinutes) => {
  if (offsetMinutes === 0) return "Z";
  const sign = offsetMinutes > 0 ? "+" : "-";
  const absoluteOffset = Math.abs(offsetMinutes);
  return `${sign}${padToTwoDigits(Math.floor(absoluteOffset / 60))}:${padToTwoDigits(absoluteOffset % 60)}`;
};

/**
 * Build an array of token definition objects for date/time formatting.
 *
 * Each element maps a formatting token (e.g. "yyyy", "MM", "hh", "a") to its
 * string value computed from the provided date component object.
 *
 * Notes:
 * - `components.month` is treated as a zero-based month index (0 = January). Tokens "M"
 *   and "MM" add 1 to this index for human-readable month numbers.
 * - "yyyy" is the full year; "yy" is the last two digits of the year.
 * - "MMMM" / "MMM" use external MONTHS_FULL / MONTHS_ABBR arrays indexed by
 *   `components.month`.
 * - "HH"/"H" are 24-hour hour representations; "hh"/"h" are 12-hour formats.
 *   For 12-hour tokens, midnight/noon is represented as 12 (i.e. uses `hour % 12 || 12`).
 * - "a" emits the meridiem in lowercase ("am" or "pm").
 * - Zero-padding for numeric tokens is performed by external helpers (`padToTwoDigits`, `padToFourDigits`).
 *
 * @param {Object} components - Date/time components.
 * @param {number} components.year - Full year (e.g. 2026).
 * @param {number} components.month - Zero-based month index (0-11).
 * @param {number} components.day - Day of month (1-31).
 * @param {number} components.hour - Hour of day (0-23).
 * @param {number} components.min - Minutes (0-59).
 * @param {number} components.sec - Seconds (0-59).
 * @returns {Array<{token: string, value: string}>} Array of token/value pairs used for formatting.
 */
const createTokenDefinitions = (components) => [
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
 * Format a Date into a string according to the provided output format and timezone.
 *
 * Behavior:
 * - If outputFormat === "epoch": returns seconds since Unix epoch as a string.
 * - If outputFormat === "epochMillis": returns milliseconds since Unix epoch as a string.
 * - If outputFormat === "iso8601": returns an ISO 8601 representation (YYYY-MM-DDTHH:mm:ss±HH:mm) using components and offset derived for the resolved timezone.
 * - Otherwise: treats outputFormat as a tokenized format string. Token definitions are built from the date components (via createTokenDefinitions(getDateComponents(...))). The formatter scans the format string left-to-right, replacing the first matching token from the token definitions; any character sequences that do not match a token are copied verbatim.
 *
 * Notes:
 * - The timezone argument defaults to "UTC" when not provided and is passed to getDateComponents to compute year/month/day/hour/min/sec/offset.
 * - The function relies on helper utilities such as getDateComponents, createTokenDefinitions, padToTwoDigits, padToFourDigits, and formatTimeZoneOffset for component extraction and formatting.
 *
 * @param {Date} date - The Date instance to format.
 * @param {string} [outputFormat] - Output format specifier: "epoch", "epochMillis", "iso8601", or a custom tokenized format string. If falsy, an empty string is returned.
 * @param {string} [timeZone="UTC"] - Timezone identifier used when extracting date components.
 * @returns {string} The formatted date string.
 */
export default function formatDate(date, outputFormat, timeZone) {
  if (outputFormat === "epoch")
    return String(Math.floor(date.getTime() / 1000));
  if (outputFormat === "epochMillis") return String(date.getTime());

  const components = getDateComponents(date, timeZone || "UTC");

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
