/** DateTime extractor — parses a date string from an element and formats it.
  *
  * Source priority:
  *   source = "attribute"  → reads the named attribute (default: "datetime")
  *   otherwise             → reads textContent
  *
  * Parsing tries each format in `formats` in order; defaults to ["ISO"].
  * Output defaults to Iso8601 in UTC.
  */
open FieldTypes

let extract: (NodeHtmlParserBinding.htmlElement, option<dateOptions>) => option<string> = (
  el,
  opts,
) => {
  let source = switch opts {
  | Some(o) => Option.getOr(o.source, "text")
  | None => "text"
  }
  let attrName = switch opts {
  | Some(o) => Option.getOr(o.attribute, "datetime")
  | None => "datetime"
  }

  let raw = if source === "attribute" {
    NodeHtmlParserBinding.getAttribute(el, attrName)->Nullable.toOption
  } else {
    Some(el.textContent)
  }

  let trimmed = switch raw {
  | None => ""
  | Some(s) => String.trim(s)
  }

  if String.length(trimmed) === 0 {
    None
  } else {
    let formats = switch opts {
    | Some(o) =>
      switch o.formats {
      | Some(fmts) if Array.length(fmts) > 0 => fmts
      | _ => ["ISO"]
      }
    | None => ["ISO"]
    }
    let output = switch opts {
    | Some(o) => Option.getOr(o.output, Iso8601)
    | None => Iso8601
    }
    let timezone = switch opts {
    | Some(o) => o.timezone
    | None => None
    }

    switch DateUtils.parseDate(trimmed, formats) {
    | None => None
    | Some(date) => Some(DateUtils.formatDate(date, output, timezone))
    }
  }
}
