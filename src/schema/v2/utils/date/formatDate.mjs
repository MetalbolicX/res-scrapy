export default function formatDateInternal(date, outputSpec, timezone) {
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

  const pad2 = n => String(n).padStart(2, "0");
  const pad4 = n => String(n).padStart(4, "0");

  const getComponents = (d, tz) => {
    if (!tz || tz === "UTC") {
      return {
        year: d.getUTCFullYear(),
        month: d.getUTCMonth(),
        day: d.getUTCDate(),
        hour: d.getUTCHours(),
        min: d.getUTCMinutes(),
        sec: d.getUTCSeconds(),
        offset: 0,
      };
    }

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

    let offsetMin = 0;
    const offsetStr = parts.timeZoneName || "";
    const om = offsetStr.match(/GMT([+-])(\d+)(?::(\d+))?/);
    if (om) {
      const sign = om[1] === "+" ? 1 : -1;
      offsetMin = sign * (parseInt(om[2], 10) * 60 + (om[3] ? parseInt(om[3], 10) : 0));
    }

    let hour = parseInt(parts.hour, 10);
    if (hour === 24) hour = 0;

    return {
      year: parseInt(parts.year, 10),
      month: parseInt(parts.month, 10) - 1,
      day: parseInt(parts.day, 10),
      hour,
      min: parseInt(parts.minute, 10),
      sec: parseInt(parts.second, 10),
      offset: offsetMin,
    };
  };

  const offsetToStr = offsetMin => {
    if (offsetMin === 0) return "Z";
    const sign = offsetMin > 0 ? "+" : "-";
    const abs = Math.abs(offsetMin);
    return `${sign}${pad2(Math.floor(abs / 60))}:${pad2(abs % 60)}`;
  };

  if (outputSpec === "epoch") return String(Math.floor(date.getTime() / 1000));
  if (outputSpec === "epochMillis") return String(date.getTime());

  const c = getComponents(date, timezone || "UTC");

  if (outputSpec === "iso8601") {
    return `${pad4(c.year)}-${pad2(c.month + 1)}-${pad2(c.day)}T${pad2(c.hour)}:${pad2(c.min)}:${pad2(c.sec)}${offsetToStr(c.offset)}`;
  }

  const tokenDefs = [
    {token: "yyyy", value: pad4(c.year)},
    {token: "yy", value: pad2(c.year % 100)},
    {token: "MMMM", value: MONTHS_FULL[c.month]},
    {token: "MMM", value: MONTHS_ABBR[c.month]},
    {token: "MM", value: pad2(c.month + 1)},
    {token: "M", value: String(c.month + 1)},
    {token: "dd", value: pad2(c.day)},
    {token: "d", value: String(c.day)},
    {token: "HH", value: pad2(c.hour)},
    {token: "H", value: String(c.hour)},
    {token: "hh", value: pad2(c.hour % 12 || 12)},
    {token: "h", value: String(c.hour % 12 || 12)},
    {token: "mm", value: pad2(c.min)},
    {token: "m", value: String(c.min)},
    {token: "ss", value: pad2(c.sec)},
    {token: "s", value: String(c.sec)},
    {token: "a", value: c.hour < 12 ? "am" : "pm"},
  ];

  let result = "";
  let remaining = outputSpec;
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
