let mapError: (result<'a, 'e1>, 'e1 => 'e2) => result<'a, 'e2>
let flatMap: (result<'a, 'e>, 'a => result<'b, 'e>) => result<'b, 'e>
let flatten: result<result<'a, 'e>, 'e> => result<'a, 'e>
let bimap: (result<'a, 'e1>, 'a => 'b, 'e1 => 'e2) => result<'b, 'e2>
