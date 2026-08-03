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
      rawFields
        .filter(function(f) { return f && typeof f === 'object' && typeof f.name === 'string'; })
        .map(function(f) { return [f.name, f]; })
    );
  }
  return rawFields;
}`)
