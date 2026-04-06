/** Schema executor: dispatches to RowExtractor or ZipExtractor
  * depending on whether schema.config.rowSelector is set.
  */

open FieldTypes

let applySchema: (NodeHtmlParserBinding.htmlElement, schema) => result<JSON.t, schemaError> = (
  document,
  schema,
) => {
  switch schema.config.rowSelector {
  | Some(_) => RowExtractor.run(document, schema)
  | None => ZipExtractor.run(document, schema)
  }
}
