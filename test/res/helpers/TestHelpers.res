open Assertions

let expectSome = (value, ~message="Expected Some(_) value") =>
  switch value {
  | Some(v) => v
  | None => {
      failWith(message)
      Obj.magic(())
    }
  }

let expectOk = (value, ~message="Expected Ok(_) result") =>
  switch value {
  | Ok(v) => v
  | Error(_) => {
      failWith(message)
      Obj.magic(())
    }
  }

let jsonFromString: string => JSON.t = raw =>
  switch NodeJsBinding.jsonParse(raw) {
  | Some(v) => v
  | None => {
      failWith("Invalid JSON literal in test")
      JSON.Encode.null
    }
  }

/* Single explicit `{..}` boundary: `jsonParse` returns `JSON.t` but some tests
   need open-object access. Named here so the coercion is easy to find. */
let asOpenObject: JSON.t => {..} = Obj.magic

let objectFromJsonString: string => {..} = raw =>
  switch NodeJsBinding.jsonParse(raw) {
  | Some(v) => asOpenObject(v)
  | None => {
      failWith("Invalid JSON object in test")
      asOpenObject(%raw("({})"))
    }
  }

let stringContains: (string, string) => bool = %raw(`(source, fragment) => source.includes(fragment)`)

let arrayFromJsonString: string => array<JSON.t> = raw =>
  switch NodeJsBinding.jsonParse(raw) {
  | Some(JSON.Array(items)) => items
  | Some(_) => {
      failWith("Expected JSON array in test")
      []
    }
  | None => {
      failWith("Invalid JSON literal in test")
      []
    }
  }

let stringArrayFromJsonString: string => array<string> = raw =>
  switch NodeJsBinding.jsonParse(raw) {
  | Some(JSON.Array(items)) => items->Array.map(v => Obj.magic(v))
  | Some(_) => {
      failWith("Expected JSON string array in test")
      []
    }
  | None => {
      failWith("Invalid JSON literal in test")
      []
    }
  }

let objectArrayFromJsonString: string => array<{..}> = raw =>
  switch NodeJsBinding.jsonParse(raw) {
  | Some(JSON.Array(items)) => items->Array.map(v => asOpenObject(v))
  | Some(_) => {
      failWith("Expected JSON object array in test")
      []
    }
  | None => {
      failWith("Invalid JSON literal in test")
      []
    }
  }

let emptyObject: {..} = %raw("({})")
