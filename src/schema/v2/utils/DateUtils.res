/** Date parsing and formatting utilities for the DateTime extractor.
  *
  * Supports special format tokens "ISO", "epoch", "epochMillis" as well as
  * custom format strings using the following tokens (matched longest-first):
  *
  *   yyyy  - 4-digit year          yy   - 2-digit year (00-49 → 20xx, 50-99 → 19xx)
  *   MMMM  - full month name       MMM  - abbreviated month name
  *   MM    - zero-padded month     M    - month (no padding)
  *   dd    - zero-padded day       d    - day (no padding)
  *   HH    - 24h hour (padded)     H    - 24h hour (no padding)
  *   hh    - 12h hour (padded)     h    - 12h hour (no padding)
  *   mm    - minutes (padded)      m    - minutes (no padding)
  *   ss    - seconds (padded)      s    - seconds (no padding)
  *   a     - am/pm
  */
open FieldTypes

type jsDate

/** Try to parse `str` using a single format specifier.
  * Returns `undefined` (= None) on failure. */
let tryParseWithFormat: (string, string) => option<jsDate> = %raw(`
(str, fmt) => {
  if (!str) return undefined;

  // Built-in specials
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

  // Custom format parsing
  const MONTHS_FULL = ["january","february","march","april","may","june",
                       "july","august","september","october","november","december"];
  const MONTHS_ABBR = ["jan","feb","mar","apr","may","jun",
                       "jul","aug","sep","oct","nov","dec"];

  // Token table — longer tokens first to avoid prefix conflicts
  const tokens = [
    { token: "yyyy",  regex: "(\\d{4})",          group: "year4"   },
    { token: "yy",    regex: "(\\d{2})",           group: "year2"   },
    { token: "MMMM",  regex: "([A-Za-z]+)",        group: "monthFull" },
    { token: "MMM",   regex: "([A-Za-z]{3})",      group: "monthAbbr" },
    { token: "MM",    regex: "(\\d{1,2})",          group: "month2"  },
    { token: "M",     regex: "(\\d{1,2})",          group: "month1"  },
    { token: "dd",    regex: "(\\d{1,2})",          group: "day2"    },
    { token: "d",     regex: "(\\d{1,2})",          group: "day1"    },
    { token: "HH",    regex: "(\\d{1,2})",          group: "hour24_2"},
    { token: "H",     regex: "(\\d{1,2})",          group: "hour24_1"},
    { token: "hh",    regex: "(\\d{1,2})",          group: "hour12_2"},
    { token: "h",     regex: "(\\d{1,2})",          group: "hour12_1"},
    { token: "mm",    regex: "(\\d{1,2})",          group: "min2"    },
    { token: "m",     regex: "(\\d{1,2})",          group: "min1"    },
    { token: "ss",    regex: "(\\d{1,2})",          group: "sec2"    },
    { token: "s",     regex: "(\\d{1,2})",          group: "sec1"    },
    { token: "a",     regex: "(am|pm|AM|PM)",       group: "ampm"    },
  ];

  // Build regex and group-name list from the format string
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
      // Literal character — escape for regex
      const ch = remaining[0].replace(/[.*+?^$()|[\]\\]/g, "\\$&").replace("{", "\\{").replace("}", "\\}");
      regexStr += ch;
      remaining = remaining.slice(1);
    }
  }

  const re = new RegExp("^" + regexStr + "$", "i");
  const m = str.match(re);
  if (!m) return undefined;

  // Extract named components
  const vals = {};
  for (let j = 0; j < groups.length; j++) {
    vals[groups[j]] = m[j + 1];
  }

  let year = 1970, month = 0, day = 1, hour = 0, min = 0, sec = 0;

  if (vals.year4)      year = parseInt(vals.year4, 10);
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
  else if (vals.month1 !== undefined)   month = parseInt(vals.month1, 10) - 1;

  if (vals.day2 !== undefined)    day = parseInt(vals.day2, 10);
  else if (vals.day1 !== undefined) day = parseInt(vals.day1, 10);

  if (vals.hour24_2 !== undefined)      hour = parseInt(vals.hour24_2, 10);
  else if (vals.hour24_1 !== undefined) hour = parseInt(vals.hour24_1, 10);
  else if (vals.hour12_2 !== undefined) {
    hour = parseInt(vals.hour12_2, 10) % 12;
    if (vals.ampm && vals.ampm.toLowerCase() === "pm") hour += 12;
  } else if (vals.hour12_1 !== undefined) {
    hour = parseInt(vals.hour12_1, 10) % 12;
    if (vals.ampm && vals.ampm.toLowerCase() === "pm") hour += 12;
  }

  if (vals.min2 !== undefined)    min = parseInt(vals.min2, 10);
  else if (vals.min1 !== undefined) min = parseInt(vals.min1, 10);

  if (vals.sec2 !== undefined)    sec = parseInt(vals.sec2, 10);
  else if (vals.sec1 !== undefined) sec = parseInt(vals.sec1, 10);

  const d = new Date(Date.UTC(year, month, day, hour, min, sec));
  return Number.isNaN(d.getTime()) ? undefined : d;
}
`)

/** Try each format in order; return the first successful parse.
  * Defaults to ["ISO"] when the array is empty. */
let parseDate: (string, array<string>) => option<jsDate> = (str, formats) => {
  let fmts = if Array.length(formats) === 0 {
    ["ISO"]
  } else {
    formats
  }
  fmts->Array.reduce(None, (acc, fmt) => {
    switch acc {
    | Some(_) => acc
    | None => tryParseWithFormat(str, fmt)
    }
  })
}

/** Low-level formatter. `outputSpec` is one of:
  *   "iso8601"     → ISO 8601 string (with timezone offset when tz != "UTC")
  *   "epoch"       → Unix seconds as string
  *   "epochMillis" → Unix milliseconds as string
  *   any other     → custom format (same token table as parsing)
  */
let formatDateInternal: (jsDate, string, string) => string = %raw(`
(date, outputSpec, timezone) => {
  const MONTHS_FULL = ["January","February","March","April","May","June",
                       "July","August","September","October","November","December"];
  const MONTHS_ABBR = ["Jan","Feb","Mar","Apr","May","Jun",
                       "Jul","Aug","Sep","Oct","Nov","Dec"];

  const pad2 = n => String(n).padStart(2, "0");
  const pad4 = n => String(n).padStart(4, "0");

  const getComponents = (d, tz) => {
    if (!tz || tz === "UTC") {
      return {
        year:  d.getUTCFullYear(),
        month: d.getUTCMonth(),      // 0-based
        day:   d.getUTCDate(),
        hour:  d.getUTCHours(),
        min:   d.getUTCMinutes(),
        sec:   d.getUTCSeconds(),
        offset: 0,                   // minutes east of UTC
      };
    }

    const fmt = new Intl.DateTimeFormat("en-US", {
      timeZone: tz,
      year: "numeric", month: "2-digit", day: "2-digit",
      hour: "2-digit", minute: "2-digit", second: "2-digit",
      hour12: false,
      timeZoneName: "shortOffset",
    });

    const parts = {};
    for (const p of fmt.formatToParts(d)) parts[p.type] = p.value;

    let offsetMin = 0;
    const offsetStr = parts.timeZoneName || "";
    const om = offsetStr.match(/GMT([+-])(\d+)(?::(\d+))?/);
    if (om) {
      const sign = om[1] === "+" ? 1 : -1;
      offsetMin = sign * (parseInt(om[2], 10) * 60 + (om[3] ? parseInt(om[3], 10) : 0));
    }

    let hour = parseInt(parts.hour, 10);
    if (hour === 24) hour = 0; // Intl sometimes returns 24 for midnight

    return {
      year:   parseInt(parts.year, 10),
      month:  parseInt(parts.month, 10) - 1, // 0-based
      day:    parseInt(parts.day, 10),
      hour,
      min:    parseInt(parts.minute, 10),
      sec:    parseInt(parts.second, 10),
      offset: offsetMin,
    };
  }

  const offsetToStr = offsetMin => {
    if (offsetMin === 0) return "Z";
    const sign = offsetMin > 0 ? "+" : "-";
    const abs  = Math.abs(offsetMin);
    return sign + pad2(Math.floor(abs / 60)) + ":" + pad2(abs % 60);
  }

  if (outputSpec === "epoch") return String(Math.floor(date.getTime() / 1000));
  if (outputSpec === "epochMillis") return String(date.getTime());

  const c = getComponents(date, timezone || "UTC");

  if (outputSpec === "iso8601") {
    return pad4(c.year) + "-" + pad2(c.month + 1) + "-" + pad2(c.day) + "T" + pad2(c.hour) + ":" + pad2(c.min) + ":" + pad2(c.sec) + offsetToStr(c.offset);
  }

  // Custom format — single-pass tokenizer to avoid substitution conflicts
  const tokenDefs = [
    { token: "yyyy",  value: pad4(c.year) },
    { token: "yy",    value: pad2(c.year % 100) },
    { token: "MMMM",  value: MONTHS_FULL[c.month] },
    { token: "MMM",   value: MONTHS_ABBR[c.month] },
    { token: "MM",    value: pad2(c.month + 1) },
    { token: "M",     value: String(c.month + 1) },
    { token: "dd",    value: pad2(c.day) },
    { token: "d",     value: String(c.day) },
    { token: "HH",    value: pad2(c.hour) },
    { token: "H",     value: String(c.hour) },
    { token: "hh",    value: pad2(c.hour % 12 || 12) },
    { token: "h",     value: String(c.hour % 12 || 12) },
    { token: "mm",    value: pad2(c.min) },
    { token: "m",     value: String(c.min) },
    { token: "ss",    value: pad2(c.sec) },
    { token: "s",     value: String(c.sec) },
    { token: "a",     value: c.hour < 12 ? "am" : "pm" },
  ];

  let result = "";
  let remaining = outputSpec;
  while (remaining.length > 0) {
    let matched = false;
    for (const def of tokenDefs) {
      if (remaining.startsWith(def.token)) {
        result = result + def.value;
        remaining = remaining.slice(def.token.length);
        matched = true;
        break;
      }
    }
    if (!matched) {
      result = result + remaining[0];
      remaining = remaining.slice(1);
    }
  }
  return result;
}
`)

/** Format a `jsDate` according to the `dateOutput` variant. */
let formatDate: (jsDate, dateOutput, option<string>) => string = (date, output, timezone) => {
  let tz = Option.getOr(timezone, "UTC")
  let spec = switch output {
  | Iso8601 => "iso8601"
  | Epoch => "epoch"
  | EpochMillis => "epochMillis"
  | Custom(fmt) => fmt
  }
  formatDateInternal(date, spec, tz)
}
