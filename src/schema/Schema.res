/** Schema router — delegates all logic to v2 implementation.
  *
  * This file maintains backwards compatibility with Main.res.
  * All types are defined in FieldTypes; the actual logic lives in src/schema/v2/.
  */

// ---------------------------------------------------------------------------
// Type aliases (implementations must match what .resi declares)
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
// Function delegation
// ---------------------------------------------------------------------------

let loadSchema = SchemaV2.loadSchema
let applySchema = SchemaV2.applySchema
