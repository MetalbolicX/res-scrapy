export default function tryParseWithFormat(str, fmt) {
  if (!str) return undefined;

  if (fmt === "ISO") {
    const d = new Date(str);
    return Number.isNaN(d.getTime()) ? undefined : d;
  }
  if (fmt === "epoch") {
    const n = parseInt(str, 10);
    if (Number.isNaN(n)) return undefined;
    const d = new Date(n * 1000);
    return Number.isNaN(d.getTime()) ? undefined : d;
  }
  if (fmt === "epochMillis") {
    const n = parseInt(str, 10);
    if (Number.isNaN(n)) return undefined;
    const d = new Date(n);
    return Number.isNaN(d.getTime()) ? undefined : d;
  }

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

  const tokens = [
    {token: "yyyy", regex: "(\\d{4})", group: "year4"},
    {token: "yy", regex: "(\\d{2})", group: "year2"},
    {token: "MMMM", regex: "([A-Za-z]+)", group: "monthFull"},
    {token: "MMM", regex: "([A-Za-z]{3})", group: "monthAbbr"},
    {token: "MM", regex: "(\\d{1,2})", group: "month2"},
    {token: "M", regex: "(\\d{1,2})", group: "month1"},
    {token: "dd", regex: "(\\d{1,2})", group: "day2"},
    {token: "d", regex: "(\\d{1,2})", group: "day1"},
    {token: "HH", regex: "(\\d{1,2})", group: "hour24_2"},
    {token: "H", regex: "(\\d{1,2})", group: "hour24_1"},
    {token: "hh", regex: "(\\d{1,2})", group: "hour12_2"},
    {token: "h", regex: "(\\d{1,2})", group: "hour12_1"},
    {token: "mm", regex: "(\\d{1,2})", group: "min2"},
    {token: "m", regex: "(\\d{1,2})", group: "min1"},
    {token: "ss", regex: "(\\d{1,2})", group: "sec2"},
    {token: "s", regex: "(\\d{1,2})", group: "sec1"},
    {token: "a", regex: "(am|pm|AM|PM)", group: "ampm"},
  ];

  let regexStr = "";
  let groups = [];
  let remaining = fmt;

  while (remaining.length > 0) {
    let matched = false;
    for (const t of tokens) {
      if (remaining.startsWith(t.token)) {
        regexStr += t.regex;
        groups = [...groups, t.group];
        remaining = remaining.slice(t.token.length);
        matched = true;
        break;
      }
    }
    if (!matched) {
      const ch = remaining[0]
        .replace(/[.*+?^$()|[\]\\]/g, "\\$&")
        .replace("{", "\\{")
        .replace("}", "\\}");
      regexStr += ch;
      remaining = remaining.slice(1);
    }
  }

  const re = new RegExp(`^${regexStr}$`, "i");
  const m = str.match(re);
  if (!m) return undefined;

  const vals = {};
  for (let j = 0; j < groups.length; j++) {
    vals[groups[j]] = m[j + 1];
  }

  let year = 1970;
  let month = 0;
  let day = 1;
  let hour = 0;
  let min = 0;
  let sec = 0;

  if (vals.year4) year = parseInt(vals.year4, 10);
  else if (vals.year2) {
    const y2 = parseInt(vals.year2, 10);
    year = y2 <= 49 ? 2000 + y2 : 1900 + y2;
  }

  if (vals.monthFull) {
    const idx = MONTHS_FULL.indexOf(vals.monthFull.toLowerCase());
    if (idx === -1) return undefined;
    month = idx;
  } else if (vals.monthAbbr) {
    const idx = MONTHS_ABBR.indexOf(vals.monthAbbr.toLowerCase());
    if (idx === -1) return undefined;
    month = idx;
  } else if (vals.month2 !== undefined) month = parseInt(vals.month2, 10) - 1;
  else if (vals.month1 !== undefined) month = parseInt(vals.month1, 10) - 1;

  if (vals.day2 !== undefined) day = parseInt(vals.day2, 10);
  else if (vals.day1 !== undefined) day = parseInt(vals.day1, 10);

  if (vals.hour24_2 !== undefined) hour = parseInt(vals.hour24_2, 10);
  else if (vals.hour24_1 !== undefined) hour = parseInt(vals.hour24_1, 10);
  else if (vals.hour12_2 !== undefined) {
    hour = parseInt(vals.hour12_2, 10) % 12;
    if (vals.ampm && vals.ampm.toLowerCase() === "pm") hour += 12;
  } else if (vals.hour12_1 !== undefined) {
    hour = parseInt(vals.hour12_1, 10) % 12;
    if (vals.ampm && vals.ampm.toLowerCase() === "pm") hour += 12;
  }

  if (vals.min2 !== undefined) min = parseInt(vals.min2, 10);
  else if (vals.min1 !== undefined) min = parseInt(vals.min1, 10);

  if (vals.sec2 !== undefined) sec = parseInt(vals.sec2, 10);
  else if (vals.sec1 !== undefined) sec = parseInt(vals.sec1, 10);

  const d = new Date(Date.UTC(year, month, day, hour, min, sec));
  return Number.isNaN(d.getTime()) ? undefined : d;
}
