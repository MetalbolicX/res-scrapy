open Test
open Assertions
open FieldTypes

test("OptionsParser.parseTextOptions parses all keys", () => {
  let field = TestHelpers.objectFromJsonString(
    "{\"textOptions\":{\"trim\":false,\"normalizeWhitespace\":true,\"lowercase\":true,\"uppercase\":false,\"pattern\":\"([0-9]+)\",\"join\":\",\"}}",
  )
  switch OptionsParser.parseTextOptions(field) {
  | Some(opts) => {
      isOptionEqualTo(Some(false), opts.trim, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(true), opts.normalizeWhitespace, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(true), opts.lowercase, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(false), opts.uppercase, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some("([0-9]+)"), opts.pattern, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(","), opts.join, ~eq=(a, b) => a == b)
    }
  | None => failWith("Expected text options")
  }
})

test("OptionsParser.parseAttributeConfig supports array and legacy key", () => {
  let arrayField = TestHelpers.objectFromJsonString(
    "{\"attributes\":[\"href\",\"src\"],\"attributeOptions\":{\"mode\":\"join\",\"joinSep\":\"|\"}}",
  )
  switch OptionsParser.parseAttributeConfig(arrayField) {
  | Some(cfg) => {
      isIntEqualTo(2, Array.length(cfg.names))
      isTruthy(cfg.mode == Join)
      isOptionEqualTo(Some("|"), cfg.joinSep, ~eq=(a, b) => a == b)
    }
  | None => failWith("Expected attribute config")
  }

  let legacyField = TestHelpers.objectFromJsonString("{\"attribute\":\"href\"}")
  switch OptionsParser.parseAttributeConfig(legacyField) {
  | Some(cfg) => {
      isIntEqualTo(1, Array.length(cfg.names))
      isTruthy(cfg.mode == First)
      isTextEqualTo("href", cfg.names[0]->Option.getOr(""))
    }
  | None => failWith("Expected legacy attribute config")
  }
})

test("OptionsParser.parseNumberOptions and parseErrorPolicy", () => {
  isTruthy(OptionsParser.parseErrorPolicy("returnText") == ReturnText)
  isTruthy(OptionsParser.parseErrorPolicy("returnDefault") == ReturnDefault)
  isTruthy(OptionsParser.parseErrorPolicy("unknown") == ReturnNull)

  let field = TestHelpers.objectFromJsonString(
    "{\"numberOptions\":{\"stripNonNumeric\":false,\"precision\":2,\"allowNegative\":false,\"onError\":\"returnText\"}}",
  )
  switch OptionsParser.parseNumberOptions(field) {
  | Some(opts) => {
      isOptionEqualTo(Some(false), opts.stripNonNumeric, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(2), opts.precision, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(false), opts.allowNegative, ~eq=(a, b) => a == b)
      isTruthy(opts.onError == Some(ReturnText))
    }
  | None => failWith("Expected number options")
  }
})

test("OptionsParser.parseBooleanOptions and unknown policy", () => {
  isTruthy(OptionsParser.parseBooleanUnknownPolicy("null") == UnknownNull)
  isTruthy(OptionsParser.parseBooleanUnknownPolicy("error") == UnknownError)
  isTruthy(OptionsParser.parseBooleanUnknownPolicy("anything") == UnknownFalse)

  let field = TestHelpers.objectFromJsonString(
    "{\"booleanOptions\":{\"mode\":\"attributeCheck\",\"attribute\":\"data-stock\",\"onUnknown\":\"error\"}}",
  )
  switch OptionsParser.parseBooleanOptions(field) {
  | Some(opts) => {
      isTruthy(opts.mode == Some(AttributeCheck))
      isOptionEqualTo(Some("data-stock"), opts.attribute, ~eq=(a, b) => a == b)
      isTruthy(opts.onUnknown == Some(UnknownError))
    }
  | None => failWith("Expected boolean options")
  }
})

test("OptionsParser.parseListOptions parses attr itemType", () => {
  let field = TestHelpers.objectFromJsonString(
    "{\"listOptions\":{\"itemType\":\"attr:data-id\",\"unique\":true,\"filter\":\"^a\",\"limit\":3,\"join\":\",\"}}",
  )
  let opts = OptionsParser.parseListOptions(field)
  switch opts.itemType {
  | ListAttribute(name) => isTextEqualTo("data-id", name)
  | _ => failWith("Expected ListAttribute itemType")
  }
  isOptionEqualTo(Some(true), opts.unique, ~eq=(a, b) => a == b)
  isOptionEqualTo(Some("^a"), opts.filter, ~eq=(a, b) => a == b)
  isOptionEqualTo(Some(3), opts.limit, ~eq=(a, b) => a == b)
  isOptionEqualTo(Some(","), opts.join, ~eq=(a, b) => a == b)
})
