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
  | Text(Some(opts)) => {
      isOptionEqualTo(Some(true), opts.trim, ~eq=(a, b) => a == b)
    }
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
