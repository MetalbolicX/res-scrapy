open FieldTypes

// @get_index external dictGet: ({..}, string) => option<'a>
let dictGet: ({..}, string) => option<'a>
let parseFieldType: ({..}, string) => result<fieldType, string>
let parseField: ({..}, string) => result<schemaField, schemaError>
