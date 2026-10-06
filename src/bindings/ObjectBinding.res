/**
  * Object-level utility bindings that cannot be expressed cleanly in pure ReScript.
  *
  * These are intentional FFI islands — minimal typed wrappers around JS built-ins
  * that would be substantially more verbose to express in ReScript.
  */
/** Normalises the `fields` value to an object, supporting both:
  * - Object format: `{"title": {"selector": ".title"}, ...}` (v2 preferred)
  * - Array format:  `[{"name": "title", "selector": ".title"}, ...]` (v1 legacy)
  */
let toFieldsObject: 'a => {..} = %raw(`function(rawFields) {
  if (Array.isArray(rawFields)) {
    return Object.fromEntries(
      rawFields.map(function(f) { return [f.name, f]; })
    );
  }
  return rawFields;
}`)

let jsonType: 'a => string = %raw(`function(value) {
  if (value === null) return "null";
  if (Array.isArray(value)) return "array";
  return typeof value;
}`)

let isObject: 'a => bool = %raw(`function(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}`)

let isArray: 'a => bool = %raw(`function(value) { return Array.isArray(value); }`)

let isNonEmptyStringArray: 'a => bool = %raw(`function(value) {
  return Array.isArray(value) && value.length > 0 && value.every(function(item) {
    return typeof item === "string";
  });
}`)

let firstNonObjectArrayIndex: 'a => option<int> = %raw(`function(value) {
  if (!Array.isArray(value)) return undefined;
  for (var index = 0; index < value.length; index++) {
    var item = value[index];
    if (item === null || typeof item !== "object" || Array.isArray(item)) return index;
  }
  return undefined;
}`)

let firstInvalidLegacyFieldIndex: 'a => option<int> = %raw(`function(value) {
  if (!Array.isArray(value)) return undefined;
  for (var index = 0; index < value.length; index++) {
    var item = value[index];
    if (item === null || typeof item !== "object" || Array.isArray(item) || typeof item.name !== "string") return index;
  }
  return undefined;
}`)

let isNonNegativeInteger: 'a => bool = %raw(`function(value) {
  return typeof value === "number" && Number.isInteger(value) && value >= 0;
}`)
