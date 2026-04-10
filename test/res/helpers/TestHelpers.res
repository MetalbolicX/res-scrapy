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
  | Some(v) => Obj.magic(v)
  | None => {
      failWith("Invalid JSON literal in test")
      JSON.Encode.null
    }
  }

let objectFromJsonString: string => {..} = raw =>
  switch NodeJsBinding.jsonParse(raw) {
  | Some(v) => Obj.magic(v)
  | None => {
      failWith("Invalid JSON object in test")
      Obj.magic(%raw("({})"))
    }
  }

let stringContains: (string, string) => bool = %raw(`(source, fragment) => source.includes(fragment)`)

let arrayFromJsonString: string => array<JSON.t> = raw =>
  switch NodeJsBinding.jsonParse(raw) {
  | Some(v) => Obj.magic(v)
  | None => {
      failWith("Invalid JSON literal in test")
      []
    }
  }
