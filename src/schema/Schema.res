/** Supported extraction types for a schema field.
  *
  * - `Text`      — `.textContent` of the matched element.
  * - `Attribute` — value of a named attribute (requires `attribute` key in the field definition).
  * - `Html`      — `.innerHTML` of the matched element.
  * - `Number`    — text content coerced to a `float`; `null` when the string is not numeric.
  * - `Boolean`   — text content coerced to `true/false` by checking `"true"` (case-insensitive).
 */
type fieldType =
  | Text
  | Attribute(string)
  | Html
  | Number
  | Boolean

/**
  * A single field definition inside a `schema.fields` object.
  *
  * - `selector`  — CSS selector evaluated relative to each root document.
  * - `fieldType` — How to extract the value once the element is found.
  * - `required`  — When `true`, a missing / non-matching element is surfaced as an error.
  * - `default`   — Fallback value used when the element is absent and `required` is `false`.
 */
type schemaField = {
  selector: string,
  fieldType: fieldType,
  required: bool,
  default: option<string>,
}

/**
  * Global run-time config embedded inside a schema document.
  *
  * - `ignoreErrors` — swallow per-field extraction errors instead of aborting.
  * - `limit`        — truncate the output array to at most this many rows (`0` = unlimited).
 */
type schemaConfig = {
  ignoreErrors: bool,
  limit: int,
}

/**
  * A fully parsed schema document ready for extraction.
  *
  * - `name`        — human-readable label (from `schema.name`, optional).
  * - `description` — free-text description (from `schema.description`, optional).
  * - `fields`      — ordered field definitions keyed by output field name.
  * - `config`      — run-time behaviour options.
 */
type schema = {
  name: option<string>,
  description: option<string>,
  fields: array<(string, schemaField)>,
  config: schemaConfig,
}

/**
  * Errors that can surface while parsing, loading, or applying a schema.
  *
  * - `InvalidJson`           — the raw string is not valid JSON.
  * - `MissingFields`         — the `"fields"` key is absent from the schema object.
  * - `InvalidFieldType`      — an unknown `"type"` string was supplied for a field.
  * - `AttributeMissingKey`   — `type` is `"attribute"` but the `"attribute"` key is absent.
  * - `FileReadError`         — the schema file could not be read from disk.
  * - `RequiredFieldMissing`  — a required field's selector produced no element at extraction time.
 */
type schemaError =
  | InvalidJson(string)
  | MissingFields(string)
  | InvalidFieldType({field: string, got: string})
  | AttributeMissingKey(string)
  | FileReadError(string)
  | RequiredFieldMissing({fieldName: string, selector: string})

// ---------------------------------------------------------------------------
// Internal unsafe JSON accessors – only used within this module.
// The input is always a freshly parsed JSON value whose shape we validate
// immediately after, so the coercions are safe in practice.
// ---------------------------------------------------------------------------

@get_index external dictGet: ({..}, string) => option<'a> = ""
@val external toFloat: string => float = "parseFloat"
@val external isNaN: float => bool = "isNaN"

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
  * Resolves a `fieldType` from the two raw JSON keys `"type"` and `"attribute"`.
  *
  * Returns `Error(InvalidFieldType)` when `type` is an unknown string, or
  * `Error(AttributeMissingKey)` when `type` is `"attribute"` but the `"attribute"`
  * key is absent from the field definition object.
 */
let parseFieldType: (string, {..}) => result<fieldType, schemaError> = (fieldName, rawField) => {
  let typeStr: option<string> = dictGet(rawField, "type")
  switch typeStr {
  | None | Some("text") => Ok(Text)
  | Some("html") => Ok(Html)
  | Some("number") => Ok(Number)
  | Some("boolean") => Ok(Boolean)
  | Some("attribute") =>
    switch (dictGet(rawField, "attribute"): option<string>) {
    | None =>
      Error(
        AttributeMissingKey(
          `Field "${fieldName}" has type "attribute" but is missing the "attribute" key`,
        ),
      )
    | Some(attr) => Ok(Attribute(attr))
    }
  | Some(other) => Error(InvalidFieldType({field: fieldName, got: other}))
  }
}

/**
  * Converts a raw JSON field-definition object into a typed `schemaField`.
  *
  * Returns `Error(MissingFields)` when `"selector"` is absent, or propagates
  * any `fieldType` parsing error.
 */
let parseField: (string, {..}) => result<schemaField, schemaError> = (fieldName, rawField) =>
  switch (dictGet(rawField, "selector"): option<string>) {
  | None => Error(MissingFields(`Field "${fieldName}" is missing the "selector" key`))
  | Some(selector) =>
    switch parseFieldType(fieldName, rawField) {
    | Error(e) => Error(e)
    | Ok(fieldType) =>
      let required: bool = (dictGet(rawField, "required"): option<bool>)->Option.getOr(false)
      let default: option<string> = dictGet(rawField, "default")
      Ok({selector, fieldType, required, default})
    }
  }

/**
  * Parses a raw JSON object string into a `schema`.
  *
  * Validates:
  * 1. The string is valid JSON (`InvalidJson`).
  * 2. A `"fields"` object is present (`MissingFields`).
  * 3. Every field entry passes `parseField` validation.
  *
  * Unknown top-level keys (e.g. `name`, `description`, `config`) are accepted
  * and defaulted when absent — they are never required.
 */
let parseSchema: string => result<schema, schemaError> = raw =>
  switch NodeJsBinding.jsonParse(raw) {
  | None => Error(InvalidJson("Schema is not valid JSON"))
  | Some(obj) => {
      let rawFields: option<{..}> = dictGet(obj, "fields")
      switch rawFields {
      | None => Error(MissingFields("Schema must contain a \"fields\" object"))
      | Some(rawFieldsInput) => {
          // Normalise: support both array format [{name, selector, …}]
          // and object format {fieldName: {selector, …}}.
          let fields: {..} = %raw(
            "(f) => Array.isArray(f) ? Object.fromEntries(f.map(item => [item.name, item])) : f"
          )(rawFieldsInput)
          let fieldNames: array<string> = %raw("Object.keys")(fields)
          let parsed = fieldNames->Array.reduce(Ok([]), (acc, name) => {
            switch acc {
            | Error(e) => Error(e)
            | Ok(arr) =>
              switch parseField(name, %raw("(fields, name) => fields[name]")(fields, name)) {
              | Error(e) => Error(e)
              | Ok(field) => {
                  arr->Array.push((name, field))
                  Ok(arr)
                }
              }
            }
          })
          switch parsed {
          | Error(e) => Error(e)
          | Ok(fieldArr) => {
              let rawConfig: option<{..}> = dictGet(obj, "config")
              let config: schemaConfig = switch rawConfig {
              | None => {ignoreErrors: false, limit: 0}
              | Some(c) => {
                  ignoreErrors: (dictGet(c, "ignoreErrors"): option<bool>)->Option.getOr(false),
                  limit: (dictGet(c, "limit"): option<Nullable.t<int>>)
                  ->Option.flatMap(n => n->Nullable.toOption)
                  ->Option.getOr(0),
                }
              }
              Ok({
                name: dictGet(obj, "name"),
                description: dictGet(obj, "description"),
                fields: fieldArr,
                config,
              })
            }
          }
        }
      }
    }
  }

/**
  * Loads and parses a schema from:
  *
  * 1. A raw JSON string (when `isInline` is `true`) — used by `--schema/-c`.
  * 2. A file path (when `isInline` is `false`) — used by `--schemaPath/-p`.
  *
  * Returns `Error(FileReadError)` when the file cannot be read, or any
  * `parseSchema` error on malformed JSON.
 */
let loadSchema: (~isInline: bool, string) => result<schema, schemaError> = (~isInline, source) => {
  if isInline {
    parseSchema(source)
  } else {
    try {
      let raw = NodeJsBinding.Fs.readFileSync(source)
      parseSchema(raw)
    } catch {
    | exn => {
        let msg = switch exn->JsExn.fromException {
        | Some(jsExn) => jsExn->JsExn.message->Option.getOr("Unknown error")
        | None => "Unknown error"
        }
        Error(FileReadError(`Could not read schema file "${source}": ${msg}`))
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Extraction
// ---------------------------------------------------------------------------

/**
  * Extracts a single value from an `htmlElement` according to a `fieldType`.
  *
  * - `Text`         → `.textContent` (trimmed).
  * - `Attribute(a)` → attribute `a`; returns `null` string if absent.
  * - `Html`         → `.innerHTML`.
  * - `Number`       → text content parsed with `parseFloat`; `null` on `NaN`.
  * - `Boolean`      → `true` when text content is `"true"` (case-insensitive).
 */
let extractValue: (NodeHtmlParserBinding.htmlElement, fieldType) => JSON.t = (el, fieldType) =>
  switch fieldType {
  | Text => el.textContent->String.trim->JSON.Encode.string
  | Html => el.innerHTML->JSON.Encode.string
  | Attribute(attr) => {
      let v: option<string> = %raw(
        "(el, attr) => el.getAttribute ? el.getAttribute(attr) : undefined"
      )(el, attr)
      switch v {
      | None => JSON.Encode.null
      | Some(s) => s->JSON.Encode.string
      }
    }
  | Number => {
      let n = el.textContent->String.trim->toFloat
      isNaN(n) ? JSON.Encode.null : n->JSON.Encode.float
    }
  | Boolean => (el.textContent->String.trim->String.toLowerCase == "true")->JSON.Encode.bool
  }

/**
  * Applies a `schema` to a parsed HTML document and returns a JSON array of
  * row objects.
  *
  * Extraction model (zip):
  * 1. Each field's selector is evaluated against the **document root** via
  *    `querySelectorAll`, producing an independent element list.
  * 2. Row count = length of the first field's match list.
  * 3. Remaining fields are indexed by position — if a field list is shorter
  *    than the first field's list, the missing positions use the field's
  *    `default` value (or `null`).
  * 4. `config.limit > 0` truncates the row count before zipping.
  * 5. `config.ignoreErrors` suppresses `RequiredFieldMissing` errors.
  *
  * Returns `Ok(JSON.t)` (a JSON array) or the first `schemaError` encountered.
 */
let applySchema: (NodeHtmlParserBinding.htmlElement, schema) => result<JSON.t, schemaError> = (
  document,
  schema,
) => {
  // Collect per-field element lists (all queries run from document root)
  let fieldLists: array<(
    string,
    schemaField,
    array<NodeHtmlParserBinding.htmlElement>,
  )> = schema.fields->Array.map(((name, field)) => {
    (name, field, document->NodeHtmlParserBinding.querySelectorAll(field.selector))
  })

  // Row count is driven by the first field
  let rowCount = switch fieldLists->Array.get(0) {
  | None => 0
  | Some((_, _, els)) => els->Array.length
  }

  let limitedCount = switch schema.config.limit {
  | 0 => rowCount
  | n => n < rowCount ? n : rowCount
  }

  let results: result<array<JSON.t>, schemaError> = Array.make(
    ~length=limitedCount,
    (),
  )->Array.reduce(Ok([]), (acc, _) => {
    switch acc {
    | Error(e) => Error(e)
    | Ok(rows) => {
        let idx = rows->Array.length
        let fieldResult: result<
          array<(string, JSON.t)>,
          schemaError,
        > = fieldLists->Array.reduce(Ok([]), (fAcc, (name, field, els)) => {
          switch fAcc {
          | Error(e) => Error(e)
          | Ok(pairs) => {
              let value: result<JSON.t, schemaError> = switch els->Array.get(idx) {
              | Some(el) => Ok(extractValue(el, field.fieldType))
              | None =>
                if field.required && !schema.config.ignoreErrors {
                  Error(RequiredFieldMissing({fieldName: name, selector: field.selector}))
                } else {
                  Ok(
                    switch field.default {
                    | Some(d) => d->JSON.Encode.string
                    | None => JSON.Encode.null
                    },
                  )
                }
              }
              switch value {
              | Error(e) => Error(e)
              | Ok(v) => {
                  pairs->Array.push((name, v))
                  Ok(pairs)
                }
              }
            }
          }
        })
        switch fieldResult {
        | Error(e) => Error(e)
        | Ok(pairs) => {
            rows->Array.push(JSON.Encode.object(Dict.fromArray(pairs)))
            Ok(rows)
          }
        }
      }
    }
  })

  switch results {
  | Error(e) => Error(e)
  | Ok(arr) => Ok(JSON.Encode.array(arr))
  }
}
