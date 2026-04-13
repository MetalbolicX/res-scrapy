/** Schema executor: dispatches to RowExtractor or ZipExtractor
  * depending on whether schema.config.rowSelector is set.
  */
open FieldTypes

module RowStrategy = RowExtractor.Strategy
module ZipStrategy = ZipExtractor.Strategy

let applySchema: (NodeHtmlParserBinding.htmlElement, schema) => result<JSON.t, schemaError> = (
  document,
  schema,
) => {
  if RowStrategy.canHandle(schema) {
    RowStrategy.execute(document, schema)
  } else if ZipStrategy.canHandle(schema) {
    ZipStrategy.execute(document, schema)
  } else {
    Error(ExtractionError("No extraction strategy matched schema"))
  }
}
