open FieldTypes

let dictGet: ({..}, string) => option<'a>
let parseFieldType: ({..}, string) => result<fieldType, string>
let parseField: ({..}, string) => result<schemaField, schemaError>
