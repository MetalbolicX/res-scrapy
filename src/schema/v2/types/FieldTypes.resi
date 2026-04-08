/** Single source-of-truth for every type used by the v2 schema pipeline.
  * All parser, extractor, and executor modules open or reference this module.
  */

// ---------------------------------------------------------------------------
// Error fallback policy
// ---------------------------------------------------------------------------

type errorPolicy =
  | ReturnNull
  | ReturnText
  | ReturnDefault

// ---------------------------------------------------------------------------
// Per-type option records
// ---------------------------------------------------------------------------

type textOptions = {
  trim?: bool,
  normalizeWhitespace?: bool,
  lowercase?: bool,
  uppercase?: bool,
  pattern?: string,
  join?: string,
}

type attrMode =
  | First
  | FirstNonEmpty
  | All
  | Join

type attributeConfig = {
  names: array<string>,
  mode: attrMode,
  joinSep?: string,
}

type htmlMode =
  | Inner
  | Outer

type htmlOptions = {
  mode?: htmlMode,
  stripScripts?: bool,
  stripStyles?: bool,
}

type numberOptions = {
  stripNonNumeric?: bool,
  pattern?: string,
  thousandsSeparator?: string,
  decimalSeparator?: string,
  precision?: int,
  allowNegative?: bool,
  onError?: errorPolicy,
}

type booleanMode =
  | Mapping
  | Presence
  | AttributeCheck

type booleanUnknownPolicy =
  | UnknownFalse
  | UnknownNull
  | UnknownError

type booleanOptions = {
  mode?: booleanMode,
  trueValues?: array<string>,
  falseValues?: array<string>,
  attribute?: string,
  onUnknown?: booleanUnknownPolicy,
}

type countOptions = {
  min?: int,
  max?: int,
}

type urlOptions = {
  base?: string,
  resolve?: bool,
  validate?: bool,
  protocol?: string,
  stripQuery?: bool,
  stripHash?: bool,
  attribute?: string,
}

type jsonOptions = {
  source?: string,
  attribute?: string,
  path?: string,
  onError?: errorPolicy,
}

type dateOutput =
  | Iso8601
  | Epoch
  | EpochMillis
  | Custom(string)

type dateOptions = {
  formats?: array<string>,
  timezone?: string,
  output?: dateOutput,
  strict?: bool,
  source?: string,
  attribute?: string,
}

type listItemType =
  | ListText
  | ListHtml
  | ListAttribute(string)
  | ListUrl

type listOptions = {
  itemType: listItemType,
  unique?: bool,
  filter?: string,
  limit?: int,
  join?: string,
}

type schemaDefaults = {
  text?: textOptions,
  number?: numberOptions,
  boolean?: booleanOptions,
  datetime?: dateOptions,
  url?: urlOptions,
}

// ---------------------------------------------------------------------------
// Field type — carries its options inline
// ---------------------------------------------------------------------------

type columnFieldType =
  | ColumnText(option<textOptions>)
  | ColumnAttribute(attributeConfig)
  | ColumnHtml(option<htmlOptions>)
  | ColumnNumber(option<numberOptions>)
  | ColumnBoolean(option<booleanOptions>)
  | ColumnUrl(option<urlOptions>)
  | ColumnJson(option<jsonOptions>)
  | ColumnDateTime(option<dateOptions>)
  | ColumnList(listOptions)

type columnField = {
  name: string,
  selector: string,
  columnType: columnFieldType,
  required: bool,
  default?: JSON.t,
}

type tableOptions = {
  rowSelector?: string,
  columns: array<columnField>,
}

type fieldType =
  | Text(option<textOptions>)
  | Attribute(attributeConfig)
  | Html(option<htmlOptions>)
  | Number(option<numberOptions>)
  | Boolean(option<booleanOptions>)
  | Count(option<countOptions>)
  | Url(option<urlOptions>)
  | Json(option<jsonOptions>)
  | DateTime(option<dateOptions>)
  | List(listOptions)
  | Table(tableOptions)

// ---------------------------------------------------------------------------
// Field, config, and schema records
// ---------------------------------------------------------------------------

type schemaField = {
  selector: string,
  fieldType: fieldType,
  required: bool,
  default?: JSON.t,
}

type schemaConfig = {
  ignoreErrors: bool,
  limit: int,
  rowSelector?: string,
  defaults?: schemaDefaults,
}

type schema = {
  version?: string,
  name?: string,
  description?: string,
  fields: array<(string, schemaField)>,
  config: schemaConfig,
}

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

type schemaError =
  | InvalidJson(string)
  | MissingFields(string)
  | InvalidFieldType({field: string, got: string})
  | AttributeMissingKey(string)
  | FileReadError(string)
  | RequiredFieldMissing({fieldName: string, selector: string})
  | ExtractionError(string)
