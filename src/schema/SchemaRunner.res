module Iter = NodeJsBinding.Iter

open FieldTypes

let hasOnlyAggregateFields = (schema: Schema.schema) =>
  schema.fields->Iter.values->Iter.every(((_, field)) =>
    switch field.fieldType {
    | Count(_) | List(_) => true
    | _ => false
    }
  )

let warnIfZipAggregateOnly = (ctx: AppContext.appContext, schema: Schema.schema) => {
  let isZipMode = switch schema.config.rowSelector {
  | None => true
  | Some(_) => false
  }
  if isZipMode && hasOnlyAggregateFields(schema) {
    ctx.io.warn(
      "Warning: schema uses zip mode (no config.rowSelector) with only aggregate fields (count/list), so no rows can be produced. Add config.rowSelector for row-based extraction.",
    )
  }
}

let loadSchema = (ctx: AppContext.appContext, source: ParseCli.schemaSource) =>
  switch source {
  | InlineJson(raw) => ctx.deps.loadSchema(~isInline=true, raw)
  | FilePath(path) => ctx.deps.loadSchema(~isInline=false, path)
  | TableSelector(_) => Error(FieldTypes.ExtractionError("Unreachable: table mode schema load"))
  }

let runSchemaMode = (
  ctx: AppContext.appContext,
  document: Document.document,
  source: ParseCli.schemaSource,
  options: ParseCli.parseOptions,
) => {
  switch loadSchema(ctx, source)->ResultX.mapError(AppError.mapSchemaError) {
  | Error(err) => {
 ctx.io.err(AppError.toMessage(err))
      ctx.io.exit(1)
    }
  | Ok(schema) => {
      warnIfZipAggregateOnly(ctx, schema)
      switch ctx.deps.applySchema(document, schema)->ResultX.mapError(AppError.mapSchemaError) {
      | Error(err) => {
 ctx.io.err(AppError.toMessage(err))
          ctx.io.exit(1)
        }
      | Ok(json) => OutputWriter.writeOutput(ctx, options, ctx.deps.stringifyJson(json))
      }
    }
  }
}