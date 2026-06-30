/** Shared field-option parsing for code paths that produce the same records
  * from raw JSON regardless of context (per-field options vs. config defaults).
  *
  * `OptionsParser` and `ConfigParser` used to carry identical inline logic for
  * text options. Centralising that logic here keeps the contract — both parsers
  * produce structurally identical textOptions records from the same input. */
open FieldTypes
open JsonUtils

let parseText: {..} => textOptions = raw => {
  let trim = dictGet(raw, "trim")
  let normalizeWhitespace = dictGet(raw, "normalizeWhitespace")
  let lowercase = dictGet(raw, "lowercase")
  let uppercase = dictGet(raw, "uppercase")
  let pattern = dictGet(raw, "pattern")
  let join = dictGet(raw, "join")
  {?trim, ?normalizeWhitespace, ?lowercase, ?uppercase, ?pattern, ?join}
}