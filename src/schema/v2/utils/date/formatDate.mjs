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
const padToTwoDigits = (value) => String(value).padStart(2, "0");
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
const padToFourDigits = (value) => String(value).padStart(4, "0");
/**
 * Parse a timezone string of the form "GMT±HH" or "GMT±HH:MM" and return the offset in minutes.
 *
 * @param timeZoneName - Optional timezone string. Expected to start with "GMT" followed immediately by '+' or '-' and hour digits, with an optional ":MM" minute component.
 * @returns The timezone offset in minutes (positive for '+' offsets, negative for '-' offsets). Returns 0 for falsy or non-matching inputs.
 *
 * @example
 * ```TypeScript
 * console.log(parseTimeZoneOffsetMinutes("GMT+02")); // Outputs: 120
 * console.log(parseTimeZoneOffsetMinutes("GMT-05:30")); // Outputs: -330
 * console.log(parseTimeZoneOffsetMinutes("GMT+00:15")); // Outputs: 15
 * console.log(parseTimeZoneOffsetMinutes("GMT-00:45")); // Outputs: -45
 * console.log(parseTimeZoneOffsetMinutes("UTC")); // Outputs: 0 (non-matching input)
 * console.log(parseTimeZoneOffsetMinutes(null)); // Outputs: 0 (falsy input)
 * console.log(parseTimeZoneOffsetMinutes(undefined)); // Outputs: 0 (falsy input)
 * ```
 *
 * @remarks
 * - The pattern matching is case-sensitive and requires the exact prefix "GMT".
 * - Hours and minutes are parsed as base-10 integers; minutes default to 0 if omitted.
 */
const parseTimeZoneOffsetMinutes = (timeZoneName) => {
    if (!timeZoneName)
        return 0;
    const match = timeZoneName.match(/GMT([+-])(\d+)(?::(\d+))?/);
    if (!match)
        return 0;
    const sign = match[1] === "+" ? 1 : -1;
    const hours = parseInt(match[2], 10) || 0;
    const minutes = parseInt(match[3] || "0", 10);
    return sign * (hours * 60 + minutes);
};
/**
 * Extracts UTC-based date and time components from the given Date.
 *
 * @param date - The Date instance to read UTC components from.
 * @returns An object with the following properties:
 *          - year: UTC full year,
 *          - month: UTC month (zero-based, 0 = January),
 *          - day: UTC day of the month,
 *          - hour: UTC hour,
 *          - min: UTC minutes,
 *          - sec: UTC seconds,
 *          - offset: timezone offset in minutes (always 0 for UTC).
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
 * Extracts localized date and time components for a given Date in a specified IANA time zone.
 *
 * Uses Intl.DateTimeFormat with the "en-US" locale and the "shortOffset" timeZoneName to produce
 * numeric year, month, day, hour, minute, second and a timezone offset string which is parsed into
 * minutes via parseTimeZoneOffsetMinutes.
 *
 * Special behaviors:
 * - The returned month is zero-indexed (0 = January).
 * - If Intl yields an hour value of 24 it is normalized to 0.
 * - If the timeZoneName part is missing or unparsable, parseTimeZoneOffsetMinutes will handle it
 *   and the returned offset may be 0 or a fallback value.
 *
 * @param date - The Date object to convert into components.
 * @param timeZone - An IANA time zone identifier (e.g. "UTC", "America/New_York").
 * @returns An object of type DateComponents containing:
 *   - year: full numeric year
 *   - month: zero-indexed month (0-11)
 *   - day: day of month
 *   - hour: hour of day (0-23)
 *   - min: minute (0-59)
 *   - sec: second (0-59)
 *   - offset: time zone offset in minutes from UTC
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
    const dateParts = Object.fromEntries(dateTimeFormatter
        .formatToParts(date)
        .map(({ type, value }) => [type, value]));
    let hour = parseInt(dateParts.hour, 10);
    if (hour === 24)
        hour = 0;
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
 * Returns the constituent date/time components for a given instant, resolved either in UTC or in a specified time zone.
 *
 * If `timeZone` is omitted or equal to `"UTC"`, UTC components are returned via `getUtcDateComponents`.
 * Otherwise, components are computed for the provided `timeZone` via `getTimeZoneDateComponents`.
 *
 * @param date - The Date instance representing the instant to extract components from.
 * @param timeZone - Optional IANA time zone identifier; use `"UTC"` to force UTC semantics.
 * @returns The DateComponents (e.g., year, month, day, hour, minute, second, millisecond) corresponding to the resolved time zone.
 */
const getDateComponents = (date, timeZone) => !timeZone || timeZone === "UTC"
    ? getUtcDateComponents(date)
    : getTimeZoneDateComponents(date, timeZone);
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
const formatTimeZoneOffset = (offsetMinutes) => {
    if (offsetMinutes === 0)
        return "Z";
    const sign = offsetMinutes > 0 ? "+" : "-";
    const absoluteOffset = Math.abs(offsetMinutes);
    return `${sign}${padToTwoDigits(Math.floor(absoluteOffset / 60))}:${padToTwoDigits(absoluteOffset % 60)}`;
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
 * Format a Date into a string according to one of several built-in formats or a custom token-based format.
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
 * @param date - The Date instance to format.
 * @param outputFormat - Optional format specifier ("epoch", "epochMillis", "iso8601", or a custom token format).
 * @param timeZone - Optional IANA time zone identifier (defaults to "UTC") used to compute date components.
 * @returns The formatted date as a string according to the requested format.
 *
 * @example
 * ```TypeScript
 * const date = new Date("2024-01-02T15:04:05Z");
 * console.log(formatDate(date, "epoch")); // Outputs: "1704654245"
 * console.log(formatDate(date, "epochMillis")); // Outputs: "1704654245000"
 * console.log(formatDate(date, "iso8601")); // Outputs: "2024-01-02T15:04:05Z"
 * console.log(formatDate(date, "yyyy/MM/dd HH:mm:ss")); // Outputs: "2024/01/02 15:04:05"
 * console.log(formatDate(date, "MMM d, yyyy h:mm a", "America/New_York")); // Outputs: "Jan 2, 2024 10:04 am"
 * ```
 *
 * @remarks
 * - The token-based formatting allows for flexible date string construction without hardcoding specific formats.
 * - Time zone handling ensures that the formatted output can reflect the correct local time for a given IANA time zone, or UTC if none is specified.
 */
export default function formatDate(date, outputFormat, timeZone) {
    if (outputFormat === "epoch")
        return String(Math.floor(date.getTime() / 1000));
    if (outputFormat === "epochMillis")
        return String(date.getTime());
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
