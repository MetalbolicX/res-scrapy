open FieldTypes

type jsDate

let tryParseWithFormat: (string, string) => option<jsDate>
let parseDate: (string, array<string>) => option<jsDate>
let formatDate: (jsDate, dateOutput, option<string>) => string
