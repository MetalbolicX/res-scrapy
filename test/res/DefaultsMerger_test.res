open Test
open Assertions
open FieldTypes
open DefaultsMerger

let _ = test("DefaultsMerger - resolveDefaults with Text field", () => {
  let defaults: schemaDefaults = {
    text: {
      trim: true,
      normalizeWhitespace: true,
      lowercase: false,
      uppercase: false,
      pattern: "abc",
      join: "",
    },
  }

  let fieldOpts: textOptions = {
    trim: false,
    normalizeWhitespace: false,
    lowercase: false,
    uppercase: true,
    pattern: "",
    join: ",",
  }

  let result = resolveDefaults(Some(defaults), Text(Some(fieldOpts)))

  switch result {
  | Text(Some(opts)) => {
      // Field overrides default
      isOptionEqualTo(Some(false), opts.trim, ~eq=(a, b) => a == b)
      // Field is false (set), so pickOption returns Some(false) — not fallback
      // Actually: pickOption(Some(false), Some(true)) => Some(false)
      isOptionEqualTo(Some(false), opts.normalizeWhitespace, ~eq=(a, b) => a == b)
      // Both false
      isOptionEqualTo(Some(false), opts.lowercase, ~eq=(a, b) => a == b)
      // Field has value
      isOptionEqualTo(Some(true), opts.uppercase, ~eq=(a, b) => a == b)
      // Default has value, field is empty string (set) so pickOption returns Some("")
      isOptionEqualTo(Some(""), opts.pattern, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(","), opts.join, ~eq=(a, b) => a == b)
    }
  | _ => failWith("Expected Text field type")
  }
})

let _ = test("DefaultsMerger - resolveDefaults with Text field when defaults has no text", () => {
  let defaults: schemaDefaults = {}

  let fieldOpts: textOptions = {
    trim: true,
    normalizeWhitespace: false,
    lowercase: false,
    uppercase: false,
    pattern: "",
    join: "",
  }

  let result = resolveDefaults(Some(defaults), Text(Some(fieldOpts)))

  switch result {
  | Text(Some(opts)) => {
      isOptionEqualTo(Some(true), opts.trim, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(false), opts.normalizeWhitespace, ~eq=(a, b) => a == b)
    }
  | _ => failWith("Expected Text field type")
  }
})

let _ = test("DefaultsMerger - resolveDefaults with Text field when fieldOpts is None", () => {
  let defaults: schemaDefaults = {
    text: {
      trim: true,
      normalizeWhitespace: false,
      lowercase: false,
      uppercase: false,
      pattern: "",
      join: "",
    },
  }

  let result = resolveDefaults(Some(defaults), Text(None))

  switch result {
  | Text(Some(opts)) => {
      // When fieldOpts is None, defaults are used: pickOption(None, Some(true)) => Some(true)
      isOptionEqualTo(Some(true), opts.trim, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(false), opts.normalizeWhitespace, ~eq=(a, b) => a == b)
    }
  | _ => failWith("Expected Text field type")
  }
})

let _ = test("DefaultsMerger - resolveDefaults with None defaults", () => {
  let fieldOpts: textOptions = {
    trim: true,
    normalizeWhitespace: false,
    lowercase: false,
    uppercase: false,
    pattern: "",
    join: "",
  }

  let result = resolveDefaults(None, Text(Some(fieldOpts)))

  switch result {
  | Text(Some(opts)) => isOptionEqualTo(Some(true), opts.trim, ~eq=(a, b) => a == b)
  | _ => failWith("Expected Text field type")
  }
})

let _ = test("DefaultsMerger - resolveDefaults with Number field", () => {
  let defaults: schemaDefaults = {
    number: {
      stripNonNumeric: true,
      pattern: "",
      thousandsSeparator: ",",
      decimalSeparator: ".",
      precision: 2,
      allowNegative: false,
      onError: ReturnNull,
    },
  }

  let fieldOpts: numberOptions = {
    stripNonNumeric: false,
    pattern: "",
    thousandsSeparator: "",
    decimalSeparator: ",",
    precision: 0,
    allowNegative: true,
    onError: ReturnText,
  }

  let result = resolveDefaults(Some(defaults), Number(Some(fieldOpts)))

  switch result {
  | Number(Some(opts)) => {
      // Field has value (false), so pickOption returns Some(false) — overrides default
      isOptionEqualTo(Some(false), opts.stripNonNumeric, ~eq=(a, b) => a == b)
      // Field is empty string, so pickOption returns Some("") — overrides default
      isOptionEqualTo(Some(""), opts.thousandsSeparator, ~eq=(a, b) => a == b)
      // decimalSeparator: field is "," so pickOption returns Some(",") — overrides default
      isOptionEqualTo(Some(","), opts.decimalSeparator, ~eq=(a, b) => a == b)
      // precision: field is 0 so pickOption returns Some(0) — overrides default
      isOptionEqualTo(Some(0), opts.precision, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(true), opts.allowNegative, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(ReturnText), opts.onError, ~eq=(a, b) => a == b)
    }
  | _ => failWith("Expected Number field type")
  }
})

let _ = test("DefaultsMerger - resolveDefaults with Boolean field", () => {
  let defaults: schemaDefaults = {
    boolean: {
      mode: Presence,
      trueValues: ["y"],
      falseValues: ["n"],
      attribute: "",
      onUnknown: UnknownFalse,
    },
  }

  let fieldOpts: booleanOptions = {
    mode: Mapping,
    trueValues: [],
    falseValues: [],
    attribute: "attr",
    onUnknown: UnknownError,
  }

  let result = resolveDefaults(Some(defaults), Boolean(Some(fieldOpts)))

  switch result {
  | Boolean(Some(opts)) => {
      // Field has Mapping, so pickOption returns Some(Mapping) — overrides default
      isOptionEqualTo(Some(Mapping), opts.mode, ~eq=(a, b) => a == b)
      // Field is empty array, so pickOption returns Some([]) — overrides default
      isOptionEqualTo(Some([]), opts.trueValues, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some("attr"), opts.attribute, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(UnknownError), opts.onUnknown, ~eq=(a, b) => a == b)
    }
  | _ => failWith("Expected Boolean field type")
  }
})

let _ = test("DefaultsMerger - resolveDefaults with other fields", () => {
  let result = resolveDefaults(None, Attribute({names: ["href"], mode: First}))
  switch result {
  | Attribute({names: ["href"]}) => passWith("Attribute passed")
  | _ => failWith("Expected Attribute")
  }

  let result = resolveDefaults(None, List({itemType: ListText}))
  switch result {
  | List(_) => passWith("List passed")
  | _ => failWith("Expected List")
  }
})

// Phase 2.1 — direct 4-quadrant characterization tests for the 7 merge*Options
// helpers. Each follows the same nested-switch shape:
//   switch defaultOpts { None => fieldOpts | Some(def) => switch fieldOpts {
//     None => Some(def) | Some(opts) => Some({...pickOption per field...})
//   }}
// These tests pin behavior so the refactor (DRY via applyDefaults + lookup) is
// provably safe. Records use partial construction (ReScript allows omitting
// optional fields); per-field assertions verify one specific override per test.

let _ = test("mergeTextOptions Q1 (None/None -> None)", () => {
  switch mergeTextOptions(None, None) {
  | None => passWith("ok")
  | Some(_) => failWith("expected None")
  }
})

let _ = test("mergeTextOptions Q2 (None/Some(d) -> Some(d))", () => {
  let d: textOptions = {trim: true}
  switch mergeTextOptions(None, Some(d)) {
  | Some(opts) => isOptionEqualTo(Some(true), opts.trim, ~eq=(a, b) => a == b)
  | None => failWith("expected Some(d)")
  }
})

let _ = test("mergeTextOptions Q3 (Some(f)/None -> Some(f))", () => {
  let f: textOptions = {trim: true}
  switch mergeTextOptions(Some(f), None) {
  | Some(opts) => isOptionEqualTo(Some(true), opts.trim, ~eq=(a, b) => a == b)
  | None => failWith("expected Some(f)")
  }
})

let _ = test("mergeTextOptions Q4 (Some(f)/Some(d) -> field wins)", () => {
  let d: textOptions = {trim: false, pattern: "D"}
  let f: textOptions = {trim: true, pattern: "F"}
  switch mergeTextOptions(Some(f), Some(d)) {
  | Some(opts) => {
      isOptionEqualTo(Some(true), opts.trim, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some("F"), opts.pattern, ~eq=(a, b) => a == b)
    }
  | None => failWith("expected Some(merged)")
  }
})

// mergeHtmlOptions

let _ = test("mergeHtmlOptions Q1 (None/None -> None)", () => {
  switch mergeHtmlOptions(None, None) {
  | None => passWith("ok")
  | Some(_) => failWith("expected None")
  }
})

let _ = test("mergeHtmlOptions Q2 (None/Some(d) -> Some(d))", () => {
  let d: htmlOptions = {mode: Outer}
  switch mergeHtmlOptions(None, Some(d)) {
  | Some(opts) => isOptionEqualTo(Some(Outer), opts.mode, ~eq=(a, b) => a == b)
  | None => failWith("expected Some(d)")
  }
})

let _ = test("mergeHtmlOptions Q3 (Some(f)/None -> Some(f))", () => {
  let f: htmlOptions = {mode: Inner}
  switch mergeHtmlOptions(Some(f), None) {
  | Some(opts) => isOptionEqualTo(Some(Inner), opts.mode, ~eq=(a, b) => a == b)
  | None => failWith("expected Some(f)")
  }
})

let _ = test("mergeHtmlOptions Q4 (Some(f)/Some(d) -> field wins)", () => {
  let d: htmlOptions = {stripScripts: false}
  let f: htmlOptions = {stripScripts: true}
  switch mergeHtmlOptions(Some(f), Some(d)) {
  | Some(opts) => isOptionEqualTo(Some(true), opts.stripScripts, ~eq=(a, b) => a == b)
  | None => failWith("expected Some(merged)")
  }
})

// mergeNumberOptions

let _ = test("mergeNumberOptions Q1 (None/None -> None)", () => {
  switch mergeNumberOptions(None, None) {
  | None => passWith("ok")
  | Some(_) => failWith("expected None")
  }
})

let _ = test("mergeNumberOptions Q2 (None/Some(d) -> Some(d))", () => {
  let d: numberOptions = {precision: 2, onError: ReturnText}
  switch mergeNumberOptions(None, Some(d)) {
  | Some(opts) => {
      isOptionEqualTo(Some(2), opts.precision, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(ReturnText), opts.onError, ~eq=(a, b) => a == b)
    }
  | None => failWith("expected Some(d)")
  }
})

let _ = test("mergeNumberOptions Q3 (Some(f)/None -> Some(f))", () => {
  let f: numberOptions = {precision: 4}
  switch mergeNumberOptions(Some(f), None) {
  | Some(opts) => isOptionEqualTo(Some(4), opts.precision, ~eq=(a, b) => a == b)
  | None => failWith("expected Some(f)")
  }
})

let _ = test("mergeNumberOptions Q4 (Some(f)/Some(d) -> field wins)", () => {
  let d: numberOptions = {precision: 2, onError: ReturnText}
  let f: numberOptions = {precision: 0, onError: ReturnNull}
  switch mergeNumberOptions(Some(f), Some(d)) {
  | Some(opts) => {
      isOptionEqualTo(Some(0), opts.precision, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(ReturnNull), opts.onError, ~eq=(a, b) => a == b)
    }
  | None => failWith("expected Some(merged)")
  }
})

// mergeBooleanOptions

let _ = test("mergeBooleanOptions Q1 (None/None -> None)", () => {
  switch mergeBooleanOptions(None, None) {
  | None => passWith("ok")
  | Some(_) => failWith("expected None")
  }
})

let _ = test("mergeBooleanOptions Q2 (None/Some(d) -> Some(d))", () => {
  let d: booleanOptions = {mode: Presence}
  switch mergeBooleanOptions(None, Some(d)) {
  | Some(opts) => isOptionEqualTo(Some(Presence), opts.mode, ~eq=(a, b) => a == b)
  | None => failWith("expected Some(d)")
  }
})

let _ = test("mergeBooleanOptions Q3 (Some(f)/None -> Some(f))", () => {
  let f: booleanOptions = {mode: Mapping}
  switch mergeBooleanOptions(Some(f), None) {
  | Some(opts) => isOptionEqualTo(Some(Mapping), opts.mode, ~eq=(a, b) => a == b)
  | None => failWith("expected Some(f)")
  }
})

let _ = test("mergeBooleanOptions Q4 (Some(f)/Some(d) -> field wins)", () => {
  let d: booleanOptions = {mode: Presence, onUnknown: UnknownFalse}
  let f: booleanOptions = {mode: Mapping, onUnknown: UnknownError}
  switch mergeBooleanOptions(Some(f), Some(d)) {
  | Some(opts) => {
      isOptionEqualTo(Some(Mapping), opts.mode, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(UnknownError), opts.onUnknown, ~eq=(a, b) => a == b)
    }
  | None => failWith("expected Some(merged)")
  }
})

// mergeDateOptions

let _ = test("mergeDateOptions Q1 (None/None -> None)", () => {
  switch mergeDateOptions(None, None) {
  | None => passWith("ok")
  | Some(_) => failWith("expected None")
  }
})

let _ = test("mergeDateOptions Q2 (None/Some(d) -> Some(d))", () => {
  let d: dateOptions = {formats: ["YYYY"]}
  switch mergeDateOptions(None, Some(d)) {
  | Some(opts) => isOptionEqualTo(Some(["YYYY"]), opts.formats, ~eq=(a, b) => a == b)
  | None => failWith("expected Some(d)")
  }
})

let _ = test("mergeDateOptions Q3 (Some(f)/None -> Some(f))", () => {
  let f: dateOptions = {output: Epoch}
  switch mergeDateOptions(Some(f), None) {
  | Some(opts) => isOptionEqualTo(Some(Epoch), opts.output, ~eq=(a, b) => a == b)
  | None => failWith("expected Some(f)")
  }
})

let _ = test("mergeDateOptions Q4 (Some(f)/Some(d) -> field wins)", () => {
  let d: dateOptions = {formats: ["YYYY"]}
  let f: dateOptions = {formats: ["DD/MM/YYYY"]}
  switch mergeDateOptions(Some(f), Some(d)) {
  | Some(opts) => isOptionEqualTo(Some(["DD/MM/YYYY"]), opts.formats, ~eq=(a, b) => a == b)
  | None => failWith("expected Some(merged)")
  }
})

// mergeUrlOptions

let _ = test("mergeUrlOptions Q1 (None/None -> None)", () => {
  switch mergeUrlOptions(None, None) {
  | None => passWith("ok")
  | Some(_) => failWith("expected None")
  }
})

let _ = test("mergeUrlOptions Q2 (None/Some(d) -> Some(d))", () => {
  let d: urlOptions = {base: "https://d"}
  switch mergeUrlOptions(None, Some(d)) {
  | Some(opts) => isOptionEqualTo(Some("https://d"), opts.base, ~eq=(a, b) => a == b)
  | None => failWith("expected Some(d)")
  }
})

let _ = test("mergeUrlOptions Q3 (Some(f)/None -> Some(f))", () => {
  let f: urlOptions = {base: "https://f"}
  switch mergeUrlOptions(Some(f), None) {
  | Some(opts) => isOptionEqualTo(Some("https://f"), opts.base, ~eq=(a, b) => a == b)
  | None => failWith("expected Some(f)")
  }
})

let _ = test("mergeUrlOptions Q4 (Some(f)/Some(d) -> field wins)", () => {
  let d: urlOptions = {base: "https://d", protocol: "https"}
  let f: urlOptions = {base: "https://f", protocol: "http"}
  switch mergeUrlOptions(Some(f), Some(d)) {
  | Some(opts) => {
      isOptionEqualTo(Some("https://f"), opts.base, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some("http"), opts.protocol, ~eq=(a, b) => a == b)
    }
  | None => failWith("expected Some(merged)")
  }
})

// mergeJsonOptions

let _ = test("mergeJsonOptions Q1 (None/None -> None)", () => {
  switch mergeJsonOptions(None, None) {
  | None => passWith("ok")
  | Some(_) => failWith("expected None")
  }
})

let _ = test("mergeJsonOptions Q2 (None/Some(d) -> Some(d))", () => {
  let d: jsonOptions = {path: "$.b"}
  switch mergeJsonOptions(None, Some(d)) {
  | Some(opts) => isOptionEqualTo(Some("$.b"), opts.path, ~eq=(a, b) => a == b)
  | None => failWith("expected Some(d)")
  }
})

let _ = test("mergeJsonOptions Q3 (Some(f)/None -> Some(f))", () => {
  let f: jsonOptions = {path: "$.a"}
  switch mergeJsonOptions(Some(f), None) {
  | Some(opts) => isOptionEqualTo(Some("$.a"), opts.path, ~eq=(a, b) => a == b)
  | None => failWith("expected Some(f)")
  }
})

let _ = test("mergeJsonOptions Q4 (Some(f)/Some(d) -> field wins)", () => {
  let d: jsonOptions = {path: "$.b", onError: ReturnText}
  let f: jsonOptions = {path: "$.a", onError: ReturnNull}
  switch mergeJsonOptions(Some(f), Some(d)) {
  | Some(opts) => {
      isOptionEqualTo(Some("$.a"), opts.path, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(ReturnNull), opts.onError, ~eq=(a, b) => a == b)
    }
  | None => failWith("expected Some(merged)")
  }
})

// resolveDefaults coverage for Html/Url/Json/DateTime (Phase 2.1)
// Existing resolveDefaults tests cover Text / Number / Boolean. The refactor
// drives all 8 visitor callbacks through a single `lookup` closure; these
// guard the remaining 4 types.

let _ = test("resolveDefaults Html field with html default", () => {
  let defaults: schemaDefaults = {html: {mode: Outer, stripScripts: true, stripStyles: false}}
  let f: htmlOptions = {mode: Inner, stripScripts: false, stripStyles: true}
  switch resolveDefaults(Some(defaults), Html(Some(f))) {
  | Html(Some(opts)) => {
      isOptionEqualTo(Some(Inner), opts.mode, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(true), opts.stripStyles, ~eq=(a, b) => a == b)
    }
  | _ => failWith("expected Html")
  }
})

let _ = test("resolveDefaults Url field with url default", () => {
  let defaults: schemaDefaults = {url: {base: "https://d", protocol: "https", stripHash: false}}
  let f: urlOptions = {base: "https://f", protocol: "http", stripHash: true}
  switch resolveDefaults(Some(defaults), Url(Some(f))) {
  | Url(Some(opts)) => {
      isOptionEqualTo(Some("https://f"), opts.base, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(true), opts.stripHash, ~eq=(a, b) => a == b)
    }
  | _ => failWith("expected Url")
  }
})

let _ = test("resolveDefaults Json field with json default", () => {
  let defaults: schemaDefaults = {json: {path: "$.b", onError: ReturnText}}
  let f: jsonOptions = {path: "$.a", onError: ReturnNull}
  switch resolveDefaults(Some(defaults), Json(Some(f))) {
  | Json(Some(opts)) => {
      isOptionEqualTo(Some("$.a"), opts.path, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(ReturnNull), opts.onError, ~eq=(a, b) => a == b)
    }
  | _ => failWith("expected Json")
  }
})
