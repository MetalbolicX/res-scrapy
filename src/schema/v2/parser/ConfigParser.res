/** Parse the top-level `config` block of a schema JSON. */
open FieldTypes

@get_index external dictGet: ({..}, string) => option<'a> = ""

let defaultConfig: schemaConfig = {ignoreErrors: false, limit: 0}

let parseConfig: {..} => schemaConfig = schemaJson => {
  switch dictGet(schemaJson, "config") {
  | None => defaultConfig
  | Some(raw) => {
      let ignoreErrors: bool = switch dictGet(raw, "ignoreErrors") {
      | Some(true) => true
      | _ => false
      }
      let limit: int =
        (dictGet(raw, "limit"): option<Nullable.t<int>>)
        ->Option.flatMap(n => n->Nullable.toOption)
        ->Option.getOr(0)
      let rowSelector: option<string> = dictGet(raw, "rowSelector")
      {ignoreErrors, limit, ?rowSelector}
    }
  }
}
