const parseISO = (input) => {
    const parsedDate = new Date(input);
    return Number.isNaN(parsedDate.getTime()) ? undefined : parsedDate;
};
const parseEpochSeconds = (secondsInput) => {
    const seconds = typeof secondsInput === "number"
        ? Math.trunc(secondsInput)
        : parseInt(String(secondsInput), 10);
    if (Number.isNaN(seconds))
        return undefined;
    const milliseconds = seconds * 1000;
    const parsedDate = new Date(milliseconds);
    return Number.isNaN(parsedDate.getTime()) ? undefined : parsedDate;
};
const parseEpochMilliseconds = (millisInput) => {
    const milliseconds = typeof millisInput === "number"
        ? Math.trunc(millisInput)
        : parseInt(String(millisInput), 10);
    if (Number.isNaN(milliseconds))
        return undefined;
    const parsedDate = new Date(milliseconds);
    return Number.isNaN(parsedDate.getTime()) ? undefined : parsedDate;
};
const parseEpochMillis = (millisInput) => parseEpochMilliseconds(millisInput);
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
const buildRegexFromFormat = (format) => {
    const sortedTokens = BASE_TOKENS.slice().sort((a, b) => b.token.length - a.token.length);
    let remaining = format;
    let pattern = "";
    const groupNames = [];
    while (remaining.length > 0) {
        const matchedToken = sortedTokens.find(({ token }) => remaining.startsWith(token));
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
    }
    catch {
        return { regex: null, groupNames: [] };
    }
};
const escapeRegexCharacter = (text) => text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const mapMatchToGroupValues = (groupNames, matches) => groupNames.reduce((mapper, groupName, i) => {
    mapper[groupName] = matches[i + 1];
    return mapper;
}, {});
const parseInteger = (rawNumber) => {
    if (rawNumber === undefined)
        return undefined;
    const n = parseInt(String(rawNumber), 10);
    return Number.isNaN(n) ? undefined : n;
};
const convert12HourTo24 = (hourValue, meridiem) => {
    const num = parseInteger(hourValue);
    if (num === undefined)
        return undefined;
    let hour = num % 12;
    if (meridiem && meridiem.toLowerCase() === "pm")
        hour += 12;
    return hour;
};
const normalizeDateParts = (tokenValues) => {
    let year = 1970;
    let month = 0;
    let day = 1;
    let hour = 0;
    let minute = 0;
    let second = 0;
    if (tokenValues.year4) {
        const n = parseInteger(tokenValues.year4);
        if (n === undefined)
            return invalidDateParts();
        year = n;
    }
    else if (tokenValues.year2) {
        const y2 = parseInteger(tokenValues.year2);
        if (y2 === undefined)
            return invalidDateParts();
        year = y2 <= 49 ? 2000 + y2 : 1900 + y2;
    }
    if (tokenValues.monthFull) {
        const idx = MONTHS_FULL.indexOf(tokenValues.monthFull.toLowerCase());
        if (idx === -1)
            return invalidDateParts();
        month = idx;
    }
    else if (tokenValues.monthAbbr) {
        const idx = MONTHS_ABBR.indexOf(tokenValues.monthAbbr.toLowerCase());
        if (idx === -1)
            return invalidDateParts();
        month = idx;
    }
    else if (tokenValues.month2 !== undefined) {
        const n = parseInteger(tokenValues.month2);
        if (n === undefined)
            return invalidDateParts();
        month = n - 1;
    }
    else if (tokenValues.month1 !== undefined) {
        const n = parseInteger(tokenValues.month1);
        if (n === undefined)
            return invalidDateParts();
        month = n - 1;
    }
    if (tokenValues.day2 !== undefined) {
        const n = parseInteger(tokenValues.day2);
        if (n === undefined)
            return invalidDateParts();
        day = n;
    }
    else if (tokenValues.day1 !== undefined) {
        const n = parseInteger(tokenValues.day1);
        if (n === undefined)
            return invalidDateParts();
        day = n;
    }
    if (tokenValues.hour24_2 !== undefined) {
        const n = parseInteger(tokenValues.hour24_2);
        if (n === undefined)
            return invalidDateParts();
        hour = n;
    }
    else if (tokenValues.hour24_1 !== undefined) {
        const n = parseInteger(tokenValues.hour24_1);
        if (n === undefined)
            return invalidDateParts();
        hour = n;
    }
    else if (tokenValues.hour12_2 !== undefined) {
        const h = convert12HourTo24(tokenValues.hour12_2, tokenValues.ampm);
        if (h === undefined)
            return invalidDateParts();
        hour = h;
    }
    else if (tokenValues.hour12_1 !== undefined) {
        const h = convert12HourTo24(tokenValues.hour12_1, tokenValues.ampm);
        if (h === undefined)
            return invalidDateParts();
        hour = h;
    }
    if (tokenValues.min2 !== undefined) {
        const n = parseInteger(tokenValues.min2);
        if (n === undefined)
            return invalidDateParts();
        minute = n;
    }
    else if (tokenValues.min1 !== undefined) {
        const n = parseInteger(tokenValues.min1);
        if (n === undefined)
            return invalidDateParts();
        minute = n;
    }
    if (tokenValues.sec2 !== undefined) {
        const n = parseInteger(tokenValues.sec2);
        if (n === undefined)
            return invalidDateParts();
        second = n;
    }
    else if (tokenValues.sec1 !== undefined) {
        const n = parseInteger(tokenValues.sec1);
        if (n === undefined)
            return invalidDateParts();
        second = n;
    }
    return { year, month, day, hour, minute, second };
};
const invalidDateParts = () => ({
    year: Number.NaN,
    month: 0,
    day: 1,
    hour: 0,
    minute: 0,
    second: 0,
});
export default function tryParseWithFormat(datetime, format) {
    if (!datetime)
        return undefined;
    if (format === "ISO")
        return parseISO(datetime);
    if (format === "epoch")
        return parseEpochSeconds(datetime);
    if (format === "epochMillis")
        return parseEpochMillis(datetime);
    if (typeof format !== "string")
        return undefined;
    const { regex, groupNames } = buildRegexFromFormat(format);
    if (!regex)
        return undefined;
    const matchResult = datetime.match(regex);
    if (!matchResult)
        return undefined;
    const tokenMap = mapMatchToGroupValues(groupNames, matchResult);
    const { year, month, day, hour, minute, second } = normalizeDateParts(tokenMap);
    const resultDate = new Date(Date.UTC(year, month, day, hour, minute, second));
    return Number.isNaN(resultDate.getTime()) ? undefined : resultDate;
}
