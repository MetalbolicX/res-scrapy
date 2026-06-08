/** Central dispatch for fieldType — the ONLY exhaustive match.
  * Each concern builds a visitor record. Adding a variant means
  * adding a callback here + implementing it in every visitor.
  */
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

let visitFieldType = (v: fieldTypeVisitor<'a>, ft: fieldType): 'a =>
  switch ft {
  | Text(opts) => v.text(opts)
  | Attribute(cfg) => v.attribute(cfg)
  | Html(opts) => v.html(opts)
  | Number(opts) => v.number(opts)
  | Boolean(opts) => v.boolean(opts)
  | Count(opts) => v.count(opts)
  | Url(opts) => v.url(opts)
  | Json(opts) => v.json(opts)
  | DateTime(opts) => v.datetime(opts)
  | List(opts) => v.list(opts)
  | Table(opts) => v.table(opts)
  }

let visitColumnFieldType = (v: columnFieldTypeVisitor<'a>, cft: columnFieldType): 'a =>
  switch cft {
  | ColumnText(opts) => v.columnText(opts)
  | ColumnAttribute(cfg) => v.columnAttribute(cfg)
  | ColumnHtml(opts) => v.columnHtml(opts)
  | ColumnNumber(opts) => v.columnNumber(opts)
  | ColumnBoolean(opts) => v.columnBoolean(opts)
  | ColumnUrl(opts) => v.columnUrl(opts)
  | ColumnJson(opts) => v.columnJson(opts)
  | ColumnDateTime(opts) => v.columnDateTime(opts)
  | ColumnList(opts) => v.columnList(opts)
  }
