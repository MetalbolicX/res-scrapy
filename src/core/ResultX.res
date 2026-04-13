let mapError: (result<'a, 'e1>, 'e1 => 'e2) => result<'a, 'e2> = (value, mapFn) =>
  switch value {
  | Ok(v) => Ok(v)
  | Error(e) => Error(mapFn(e))
  }

let flatMap: (result<'a, 'e>, 'a => result<'b, 'e>) => result<'b, 'e> = (value, mapFn) =>
  switch value {
  | Ok(v) => mapFn(v)
  | Error(e) => Error(e)
  }

let flatten: result<result<'a, 'e>, 'e> => result<'a, 'e> = value =>
  switch value {
  | Ok(inner) => inner
  | Error(e) => Error(e)
  }

let bimap: (result<'a, 'e1>, 'a => 'b, 'e1 => 'e2) => result<'b, 'e2> = (value, okMap, errMap) =>
  switch value {
  | Ok(v) => Ok(okMap(v))
  | Error(e) => Error(errMap(e))
  }
