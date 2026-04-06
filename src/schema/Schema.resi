/** Public interface for schema loading and extraction.
  *
  * All types are v2 (from FieldTypes). Main.res depends on these types
  * and the two public functions only — nothing else in this file is
  * part of the external API.
  */

// ---------------------------------------------------------------------------
// Re-exported v2 types
// ---------------------------------------------------------------------------

type errorPolicy = FieldTypes.errorPolicy
type textOptions = FieldTypes.textOptions
type attrMode = FieldTypes.attrMode
type attributeConfig = FieldTypes.attributeConfig
type htmlMode = FieldTypes.htmlMode
type htmlOptions = FieldTypes.htmlOptions
type numberOptions = FieldTypes.numberOptions
type booleanMode = FieldTypes.booleanMode
type booleanOptions = FieldTypes.booleanOptions
type fieldType = FieldTypes.fieldType
type schemaField = FieldTypes.schemaField
type schemaConfig = FieldTypes.schemaConfig
type schema = FieldTypes.schema
type schemaError = FieldTypes.schemaError

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

let loadSchema: (~isInline: bool, string) => result<schema, schemaError>
let applySchema: (NodeHtmlParserBinding.htmlElement, schema) => result<JSON.t, schemaError>
