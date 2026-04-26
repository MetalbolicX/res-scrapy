let message = exn =>
  switch exn->JsExn.fromException {
  | Some(jsExn) => jsExn->JsExn.message->Option.getOr("Unknown error")
  | None => "Unknown error"
  }
