open FieldTypes

type jsInstant

let tryParseWithFormat: (string, string) => option<jsInstant>
let parseDate: (string, array<string>) => option<jsInstant>
let formatDate: (jsInstant, dateOutput, option<string>) => string
