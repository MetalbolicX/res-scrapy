open FieldTypes

let parseFieldType: ({..}, string) => result<fieldType, string>
let parseField: ({..}, string) => result<schemaField, schemaError>
