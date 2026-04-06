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

type booleanOptions = {
  mode?: booleanMode,
  trueValues?: array<string>,
  falseValues?: array<string>,
  attribute?: string,
  onUnknown?: bool,
}

// ---------------------------------------------------------------------------
// Field type — carries its options inline
// ---------------------------------------------------------------------------

type fieldType =
  | Text(option<textOptions>)
  | Attribute(attributeConfig)
  | Html(option<htmlOptions>)
  | Number(option<numberOptions>)
  | Boolean(option<booleanOptions>)

// ---------------------------------------------------------------------------
// Field, config, and schema records
// ---------------------------------------------------------------------------

type schemaField = {
  selector: string,
  fieldType: fieldType,
  required: bool,
  default?: string,
}

type schemaConfig = {
  ignoreErrors: bool,
  limit: int,
  rowSelector?: string,
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
