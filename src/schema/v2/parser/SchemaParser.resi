open FieldTypes

// @get_index external dictGet: ({..}, string) => option<'a>
let dictGet: ({..}, string) => option<'a>

let parseSchema: 'a => result<schema, schemaError>
