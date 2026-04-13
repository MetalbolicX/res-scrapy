/** Top-level schema parser.
  * Turns a raw parsed JSON value into a typed `schema` record,
  * or returns a `schemaError`.
  */
open FieldTypes
open JsonUtils

/** Normalise the `fields` value to an object, supporting both:
  * - Object format: `{"title": {"selector": ".title"}, ...}` (v2 preferred)
  * - Array format:  `[{"name": "title", "selector": ".title"}, ...]` (v1 legacy)
  */
let toFieldsObject: 'a => {..} = %raw(`
  (rawFields) => {
    if (Array.isArray(rawFields)) {
      return Object.fromEntries(
        rawFields
          .filter(f => f && typeof f === 'object' && typeof f.name === 'string')
          .map(({ name, ...rest }) => [name, rest])
      );
    }
    return rawFields;
  }
`)

/** Convert the `fields` object (keys → field defs) into a sorted array. */
let normalizeFields: {..} => result<array<(string, schemaField)>, schemaError> = fieldsObj => {
  // Collect all own keys then parse each field
  let keys: array<string> = %raw(`(obj) => Object.keys(obj)`)(fieldsObj)
  let acc = ref([])
  let err = ref(None)
  keys->Array.forEach(key => {
    if err.contents->Option.isNone {
      switch dictGet(fieldsObj, key) {
      | None => ()
      | Some(fieldJson) =>
        switch FieldParser.parseField(fieldJson, key) {
        | Error(e) => err := Some(e)
        | Ok(field) => acc := Array.concat(acc.contents, [(key, field)])
        }
      }
    }
  })
  switch err.contents {
  | Some(e) => Error(e)
  | None => Ok(acc.contents)
  }
}

/** Parse a complete schema from a raw JSON value.
  * Returns `Error(schemaError)` on any structural problem. */
let parseSchema: 'a => result<schema, schemaError> = jsonValue => {
  let raw: {..} = Obj.magic(jsonValue)
  switch dictGet(raw, "fields") {
  | None => Error(MissingFields("Schema JSON is missing the \"fields\" key"))
  | Some(fieldsRaw) =>
    let fieldsObj = toFieldsObject(fieldsRaw)
    switch normalizeFields(fieldsObj) {
    | Error(e) => Error(e)
    | Ok(fields) => {
        let config = ConfigParser.parseConfig(raw)
        let version: option<string> = dictGet(raw, "version")
        let name: option<string> = dictGet(raw, "name")
        let description: option<string> = dictGet(raw, "description")
        Ok({?version, ?name, ?description, fields, config})
      }
    }
  }
}
