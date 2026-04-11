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
const getUtcDateComponents = (date) => ({
    year: date.getUTCFullYear(),
    month: date.getUTCMonth(),
    day: date.getUTCDate(),
    hour: date.getUTCHours(),
    min: date.getUTCMinutes(),
    sec: date.getUTCSeconds(),
    offset: 0,
});
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
    const dateParts = Object.fromEntries(dateTimeFormatter.formatToParts(date).map(({ type, value }) => [type, value]));
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
const getDateComponents = (date, timeZone) => !timeZone || timeZone === "UTC"
    ? getUtcDateComponents(date)
    : getTimeZoneDateComponents(date, timeZone);
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
