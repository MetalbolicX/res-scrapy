open FieldTypes

let dictGet: ({..}, string) => option<'a>
let parseSchema: 'a => result<schema, schemaError>
