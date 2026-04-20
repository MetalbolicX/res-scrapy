open Test
open Assertions

test("AppError.mapParseError maps MissingSelector to CliError", () => {
  switch AppError.mapParseError(MissingSelector("Selector is required")) {
  | CliError(msg) => isTextEqualTo("Selector is required", msg)
  | _ => failWith("Expected CliError")
  }
})

test("AppError.mapStdInError maps stdin variants to InputError", () => {
  switch AppError.mapStdInError(EmptyContent("empty")) {
  | InputError(msg) => isTextEqualTo("empty", msg)
  | _ => failWith("Expected InputError")
  }
})

test("AppError.mapSchemaError maps InvalidFieldType message", () => {
  let err = FieldTypes.InvalidFieldType({field: "price", got: "weird"})
  switch AppError.mapSchemaError(err) {
  | SchemaError(msg) =>
    isTextEqualTo("Invalid field type \"weird\" for field \"price\"", msg)
  | _ => failWith("Expected SchemaError")
  }
})

test("AppError.mapSchemaError maps RequiredFieldMissing to ExtractionError", () => {
  let err = FieldTypes.RequiredFieldMissing({fieldName: "price", selector: ".price"})
  switch AppError.mapSchemaError(err) {
  | ExtractionError(msg) =>
    isTextEqualTo("Required field \"price\" not found for selector \".price\"", msg)
  | _ => failWith("Expected ExtractionError")
  }
})

test("AppError.toMessage returns underlying message", () => {
  isTextEqualTo("boom", AppError.toMessage(FileError("boom")))
})

test("AppError.toMessage returns write error message", () => {
  isTextEqualTo("cannot write", AppError.toMessage(WriteError("cannot write")))
})
