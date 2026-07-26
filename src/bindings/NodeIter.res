type t<'a> = Iterator.t<'a>

// Static factory methods (Iterator.from)
@val @scope("Iterator") external fromArray: array<'a> => t<'a> = "from"
@val @scope("Iterator") external fromSet: Set.t<'a> => t<'a> = "from"
@val @scope("Iterator") external fromMap: Map.t<'k, 'v> => t<('k, 'v)> = "from"

// Array iterator constructors
@send external values: array<'a> => t<'a> = "values"
@send external entries: array<'a> => t<(int, 'a)> = "entries"
@send external keys: array<'a> => t<int> = "keys"

// Lazy pipeline methods
@send external map: (t<'a>, 'a => 'b) => t<'b> = "map"
@send external filter: (t<'a>, 'a => bool) => t<'a> = "filter"
@send external take: (t<'a>, int) => t<'a> = "take"
@send external drop: (t<'a>, int) => t<'a> = "drop"
@send external forEach: (t<'a>, 'a => unit) => unit = "forEach"
@send external toArray: t<'a> => array<'a> = "toArray"
@send external every: (t<'a>, 'a => bool) => bool = "every"
@send external some: (t<'a>, 'a => bool) => bool = "some"
@send external reduce: (t<'a>, ('b, 'a) => 'b, 'b) => 'b = "reduce"
@send external reduce1: (t<'a>, ('a, 'a) => 'a) => 'a = "reduce"
@send @return(nullable) external find: (t<'a>, 'a => bool) => option<'a> = "find"
@send external flatMap: (t<'a>, 'a => t<'b>) => t<'b> = "flatMap"
