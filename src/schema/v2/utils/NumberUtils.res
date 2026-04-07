/** Numeric parsing helpers.
  * Handles currency prefixes, thousand separators, custom decimal separators,
  * and precision rounding.
  */
open FieldTypes

let parseFloat_: string => float = %raw(`(text) => parseFloat(text)`)

let isNaN_: float => bool = %raw(`(num) => isNaN(num)`)

let applyPrecision: (float, int) => float = %raw(`(num, exponent) => {
    // const factor = Math.pow(10, exponent);
    const factor = 10 ** exponent;
    return Math.round(num * factor) / factor;
  }
`)

/** Full pipeline: pattern | strip | separator normalise | parseFloat | precision */
let parseWithOptions: (string, option<numberOptions>) => option<float> = (raw, opts) => {
  let s = ref(String.trim(raw))

  // 1. Pattern extraction (dot access gives option<string>)
  switch opts {
  | Some(o) =>
    switch o.pattern {
    | Some(pat) =>
      switch StringUtils.extractPattern(s.contents, pat) {
      | Some(extracted) => s := extracted
      | None => ()
      }
    | None => ()
    }
  | None => ()
  }

  // 2. Strip non-numeric characters (default: true)
  let shouldStrip = switch opts {
  | Some(o) =>
    switch o.stripNonNumeric {
    | Some(false) => false
    | _ => true
    }
  | None => true
  }
  if shouldStrip {
    s := StringUtils.stripNonNumeric(s.contents)
  }

  // 3. Remove thousands separator
  switch opts {
  | Some(o) =>
    switch o.thousandsSeparator {
    | Some(sep) if sep !== "" => s := StringUtils.replaceAll(s.contents, sep, "")
    | _ => ()
    }
  | None => ()
  }

  // 4. Normalise decimal separator to "."
  switch opts {
  | Some(o) =>
    switch o.decimalSeparator {
    | Some(dec) if dec !== "" && dec !== "." => s := StringUtils.replaceAll(s.contents, dec, ".")
    | _ => ()
    }
  | None => ()
  }

  // 5. Parse
  if s.contents === "" {
    None
  } else {
    let n = parseFloat_(s.contents)
    if isNaN_(n) {
      None
    } else {
      // 6. Precision
      let result = switch opts {
      | Some(o) =>
        switch o.precision {
        | Some(p) => applyPrecision(n, p)
        | None => n
        }
      | None => n
      }
      // 7. Negative guard
      switch opts {
      | Some(o) if o.allowNegative == Some(false) && result < 0.0 => None
      | _ => Some(result)
      }
    }
  }
}
