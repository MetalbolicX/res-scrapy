/** Interface for FieldTypeVisitor — exposes visitor types and dispatch functions. */
open FieldTypes

type fieldTypeVisitor<'a> = {
  text: option<textOptions> => 'a,
  attribute: attributeConfig => 'a,
  html: option<htmlOptions> => 'a,
  number: option<numberOptions> => 'a,
  boolean: option<booleanOptions> => 'a,
  count: option<countOptions> => 'a,
  url: option<urlOptions> => 'a,
  json: option<jsonOptions> => 'a,
  datetime: option<dateOptions> => 'a,
  list: listOptions => 'a,
  table: tableOptions => 'a,
}

type columnFieldTypeVisitor<'a> = {
  columnText: option<textOptions> => 'a,
  columnAttribute: attributeConfig => 'a,
  columnHtml: option<htmlOptions> => 'a,
  columnNumber: option<numberOptions> => 'a,
  columnBoolean: option<booleanOptions> => 'a,
  columnUrl: option<urlOptions> => 'a,
  columnJson: option<jsonOptions> => 'a,
  columnDateTime: option<dateOptions> => 'a,
  columnList: listOptions => 'a,
}

let visitFieldType: (fieldTypeVisitor<'a>, fieldType) => 'a
let visitColumnFieldType: (columnFieldTypeVisitor<'a>, columnFieldType) => 'a
