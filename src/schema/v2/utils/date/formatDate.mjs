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
const padToTwoDigits = (value) => String(value).padStart(2, "0");
const padToFourDigits = (value) => String(value).padStart(4, "0");
const getDateComponents = (instant, timeZone) => {
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
const formatTimeZoneOffset = (offsetMinutes) => {
    if (offsetMinutes === 0)
        return "Z";
    const sign = offsetMinutes > 0 ? "+" : "-";
    const absoluteOffset = Math.abs(offsetMinutes);
    return `${sign}${padToTwoDigits(Math.floor(absoluteOffset / 60))}:${padToTwoDigits(absoluteOffset % 60)}`;
};
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
export default function formatDate(instant, outputFormat, timeZone) {
    if (outputFormat === "epoch")
        return String(Math.floor(instant.epochMilliseconds / 1000));
    if (outputFormat === "epochMillis")
        return String(instant.epochMilliseconds);
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
