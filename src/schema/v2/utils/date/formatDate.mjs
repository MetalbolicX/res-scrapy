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
 * @param {number|string} n - The value to format.
 * @returns {string} The value converted to a string and left-padded with '0' to at least two characters.
 */
const pad2 = (n) => String(n).padStart(2, "0");
/**
 * Pads a value to at least four characters with leading zeros.
 *
 * @param {number|string} n - The value to pad; will be converted to a string.
 * @returns {string} The input as a string left-padded with zeros to a minimum length of 4.
 */
const pad4 = (n) => String(n).padStart(4, "0");

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
 * parseOffsetFromTimeZoneName('GMT+2');       // returns 120
 * parseOffsetFromTimeZoneName('GMT-05:30');   // returns -330
 * parseOffsetFromTimeZoneName(null);          // returns 0
 * ```
 */
const parseOffsetFromTimeZoneName = (timeZoneName) => {
  if (!timeZoneName) return 0;
  const m = timeZoneName.match(/GMT([+-])(\d+)(?::(\d+))?/);
  if (!m) return 0;
  const sign = m[1] === "+" ? 1 : -1;
  const hours = parseInt(m[2], 10) || 0;
  const mins = parseInt(m[3] || "0", 10);
  return sign * (hours * 60 + mins);
};

/**
 * Extract UTC date/time components from a Date object.
 *
 * @param {Date} d - The Date instance to read UTC values from.
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
const getUtcComponents = (d) => ({
  year: d.getUTCFullYear(),
  month: d.getUTCMonth(),
  day: d.getUTCDate(),
  hour: d.getUTCHours(),
  min: d.getUTCMinutes(),
  sec: d.getUTCSeconds(),
  offset: 0,
});

/**
 * Get numeric date/time components for a Date in a specific IANA timezone.
 *
 * @param {Date} d - The Date instance to format.
 * @param {string} tz - IANA timezone identifier (e.g. "America/New_York").
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
 * getTzComponents(date, 'America/New_York');
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
const getTzComponents = (d, tz) => {
  const fmt = new Intl.DateTimeFormat("en-US", {
    timeZone: tz,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
    timeZoneName: "shortOffset",
  });

  const parts = {};
  for (const p of fmt.formatToParts(d)) parts[p.type] = p.value;

  let hour = parseInt(parts.hour, 10);
  if (hour === 24) hour = 0;

  return {
    year: parseInt(parts.year, 10),
    month: parseInt(parts.month, 10) - 1,
    day: parseInt(parts.day, 10),
    hour,
    min: parseInt(parts.minute, 10),
    sec: parseInt(parts.second, 10),
    offset: parseOffsetFromTimeZoneName(parts.timeZoneName || ""),
  };
};

/**
 * Get date/time components for a given Date either in UTC or a specified timezone.
 *
 * @param {Date} d - The Date object to extract components from.
 * @param {string} [tz] - Optional IANA timezone identifier. If omitted or equal to "UTC", UTC components are returned.
 * @returns {Object} An object containing individual date/time components (e.g. year, month, day, hour, minute, second, millisecond). The exact shape may vary depending on whether UTC or timezone-specific helpers are used.
 */
const getComponents = (d, tz) => {
  if (!tz || tz === "UTC") return getUtcComponents(d);
  return getTzComponents(d, tz);
};

/**
 * Convert a timezone offset in minutes to an RFC-3339 style timezone string.
 *
 * @param {number} offsetMin - Offset from UTC in minutes. Positive values indicate
 *                             timezones ahead of UTC.
 * @returns {string} "Z" for zero offset, otherwise a string in the form "+HH:MM" or "-HH:MM".
 * @example
 * ```JavaScript
 * offsetToStr(0);    // returns "Z"
 * offsetToStr(120);  // returns "+02:00"
 * offsetToStr(-330); // returns "-05:30"
 * ```
 */
const offsetToStr = (offsetMin) => {
  if (offsetMin === 0) return "Z";
  const sign = offsetMin > 0 ? "+" : "-";
  const abs = Math.abs(offsetMin);
  return `${sign}${pad2(Math.floor(abs / 60))}:${pad2(abs % 60)}`;
};

/**
 * Build an array of token definition objects for date/time formatting.
 *
 * Each element maps a formatting token (e.g. "yyyy", "MM", "hh", "a") to its
 * string value computed from the provided date component object.
 *
 * Notes:
 * - `c.month` is treated as a zero-based month index (0 = January). Tokens "M"
 *   and "MM" add 1 to this index for human-readable month numbers.
 * - "yyyy" is the full year; "yy" is the last two digits of the year.
 * - "MMMM" / "MMM" use external MONTHS_FULL / MONTHS_ABBR arrays indexed by
 *   `c.month`.
 * - "HH"/"H" are 24-hour hour representations; "hh"/"h" are 12-hour formats.
 *   For 12-hour tokens, midnight/noon is represented as 12 (i.e. uses `hour % 12 || 12`).
 * - "a" emits the meridiem in lowercase ("am" or "pm").
 * - Zero-padding for numeric tokens is performed by external helpers (`pad2`, `pad4`).
 *
 * @param {Object} c - Date/time components.
 * @param {number} c.year - Full year (e.g. 2026).
 * @param {number} c.month - Zero-based month index (0-11).
 * @param {number} c.day - Day of month (1-31).
 * @param {number} c.hour - Hour of day (0-23).
 * @param {number} c.min - Minutes (0-59).
 * @param {number} c.sec - Seconds (0-59).
 * @returns {Array<{token: string, value: string}>} Array of token/value pairs used for formatting.
 */
const buildTokenDefs = (c) => [
  { token: "yyyy", value: pad4(c.year) },
  { token: "yy", value: pad2(c.year % 100) },
  { token: "MMMM", value: MONTHS_FULL[c.month] },
  { token: "MMM", value: MONTHS_ABBR[c.month] },
  { token: "MM", value: pad2(c.month + 1) },
  { token: "M", value: String(c.month + 1) },
  { token: "dd", value: pad2(c.day) },
  { token: "d", value: String(c.day) },
  { token: "HH", value: pad2(c.hour) },
  { token: "H", value: String(c.hour) },
  { token: "hh", value: pad2(c.hour % 12 || 12) },
  { token: "h", value: String(c.hour % 12 || 12) },
  { token: "mm", value: pad2(c.min) },
  { token: "m", value: String(c.min) },
  { token: "ss", value: pad2(c.sec) },
  { token: "s", value: String(c.sec) },
  { token: "a", value: c.hour < 12 ? "am" : "pm" },
];

/**
 * Format a Date into a string according to the provided output specification and timezone.
 *
 * Behavior:
 * - If outputSpec === "epoch": returns seconds since Unix epoch as a string.
 * - If outputSpec === "epochMillis": returns milliseconds since Unix epoch as a string.
 * - If outputSpec === "iso8601": returns an ISO 8601 representation (YYYY-MM-DDTHH:mm:ss±HH:mm) using components and offset derived for the resolved timezone.
 * - Otherwise: treats outputSpec as a tokenized format string. Token definitions are built from the date components (via buildTokenDefs(getComponents(...))). The formatter scans the format string left-to-right, replacing the first matching token from the token definitions; any character sequences that do not match a token are copied verbatim.
 *
 * Notes:
 * - The timezone argument defaults to "UTC" when not provided and is passed to getComponents to compute year/month/day/hour/min/sec/offset.
 * - The function relies on helper utilities such as getComponents, buildTokenDefs, pad2, pad4, and offsetToStr for component extraction and formatting.
 *
 * @param {Date} date - The Date instance to format.
 * @param {string} [outputSpec] - Output format specifier: "epoch", "epochMillis", "iso8601", or a custom tokenized format string. If falsy, an empty string is returned.
 * @param {string} [timezone="UTC"] - Timezone identifier used when extracting date components.
 * @returns {string} The formatted date string.
 */
export default function formatDateInternal(date, outputSpec, timezone) {
  if (outputSpec === "epoch") return String(Math.floor(date.getTime() / 1000));
  if (outputSpec === "epochMillis") return String(date.getTime());

  const c = getComponents(date, timezone || "UTC");

  if (outputSpec === "iso8601") {
    return `${pad4(c.year)}-${pad2(c.month + 1)}-${pad2(c.day)}T${pad2(c.hour)}:${pad2(c.min)}:${pad2(c.sec)}${offsetToStr(c.offset)}`;
  }

  const tokenDefs = buildTokenDefs(c);

  let result = "";
  let remaining = outputSpec || "";

  while (remaining.length > 0) {
    let matched = false;
    for (const def of tokenDefs) {
      if (remaining.startsWith(def.token)) {
        result += def.value;
        remaining = remaining.slice(def.token.length);
        matched = true;
        break;
      }
    }
    if (!matched) {
      result += remaining[0];
      remaining = remaining.slice(1);
    }
  }

  return result;
}
