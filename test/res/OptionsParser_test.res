open Test
open Assertions
open TestHelpers
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

test("OptionsParser.parseHtmlOptions parses mode and strip flags", () => {
  let field = TestHelpers.objectFromJsonString(
    "{\"htmlOptions\":{\"mode\":\"outer\",\"stripScripts\":true,\"stripStyles\":false}}",
  )
  switch OptionsParser.parseHtmlOptions(field) {
  | Some(opts) => {
      isTruthy(opts.mode == Some(Outer))
      isOptionEqualTo(Some(true), opts.stripScripts, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(false), opts.stripStyles, ~eq=(a, b) => a == b)
    }
  | None => failWith("Expected html options")
  }
})

test("OptionsParser.parseCountOptions parses min and max", () => {
  let field = TestHelpers.objectFromJsonString("{\"countOptions\":{\"min\":1,\"max\":3}}")
  switch OptionsParser.parseCountOptions(field) {
  | Some(opts) => {
      isOptionEqualTo(Some(1), opts.min, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(3), opts.max, ~eq=(a, b) => a == b)
    }
  | None => failWith("Expected count options")
  }
})

test("OptionsParser.parseUrlOptions parses all keys", () => {
  let field = TestHelpers.objectFromJsonString(
    "{\"urlOptions\":{\"base\":\"https://example.com\",\"resolve\":true,\"validate\":true,\"protocol\":\"https\",\"stripQuery\":true,\"stripHash\":true,\"attribute\":\"data-url\"}}",
  )
  switch OptionsParser.parseUrlOptions(field) {
  | Some(opts) => {
      isOptionEqualTo(Some("https://example.com"), opts.base, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(true), opts.resolve, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(true), opts.validate, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some("https"), opts.protocol, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(true), opts.stripQuery, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(true), opts.stripHash, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some("data-url"), opts.attribute, ~eq=(a, b) => a == b)
    }
  | None => failWith("Expected url options")
  }
})

test("OptionsParser.parseJsonOptions parses source path and onError", () => {
  let field = TestHelpers.objectFromJsonString(
    "{\"jsonOptions\":{\"source\":\"attribute\",\"attribute\":\"data-json\",\"path\":\"item.price\",\"onError\":\"returnText\"}}",
  )
  switch OptionsParser.parseJsonOptions(field) {
  | Some(opts) => {
      isOptionEqualTo(Some("attribute"), opts.source, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some("data-json"), opts.attribute, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some("item.price"), opts.path, ~eq=(a, b) => a == b)
      isTruthy(opts.onError == Some(ReturnText))
    }
  | None => failWith("Expected json options")
  }
})

test("OptionsParser.parseDateOptions parses output strict source and attribute", () => {
  let field = TestHelpers.objectFromJsonString(
    "{\"dateOptions\":{\"formats\":[\"yyyy-MM-dd\",\"ISO\"],\"timezone\":\"UTC\",\"output\":\"custom\",\"outputFormat\":\"MM/dd/yyyy\",\"strict\":true,\"source\":\"attribute\",\"attribute\":\"datetime\"}}",
  )
  switch OptionsParser.parseDateOptions(field) {
  | Some(opts) => {
      isOptionEqualTo(Some("UTC"), opts.timezone, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(true), opts.strict, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some("attribute"), opts.source, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some("datetime"), opts.attribute, ~eq=(a, b) => a == b)
      switch opts.output {
      | Some(Custom(fmt)) => isTextEqualTo("MM/dd/yyyy", fmt)
      | _ => failWith("Expected Custom output")
      }
      let formats: array<string> = opts.formats->Option.getOr([])
      isIntEqualTo(2, formats->Array.length)
      isTextEqualTo("yyyy-MM-dd", formats->Array.get(0)->Option.getOr(""))
      isTextEqualTo("ISO", formats->Array.get(1)->Option.getOr(""))
    }
  | None => failWith("Expected date options")
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

test("OptionsParser.parseTableOptions returns Error when tableOptions is missing", () => {
  let field = TestHelpers.objectFromJsonString("{}")
  switch OptionsParser.parseTableOptions(field) {
  | Ok(_) => failWith("Expected Error for missing tableOptions")
  | Error(msg) => stringContains(msg, "tableOptions")->isTruthy
  }
})

test("OptionsParser.parseTableOptions returns Error when columns is missing", () => {
  let field = TestHelpers.objectFromJsonString("{\"tableOptions\":{}}")
  switch OptionsParser.parseTableOptions(field) {
  | Ok(_) => failWith("Expected Error for missing columns")
  | Error(msg) => stringContains(msg, "columns")->isTruthy
  }
})

test("OptionsParser.parseTableOptions returns Error when columns is empty", () => {
  let field = TestHelpers.objectFromJsonString("{\"tableOptions\":{\"columns\":[]}}")
  switch OptionsParser.parseTableOptions(field) {
  | Ok(_) => failWith("Expected Error for empty columns")
  | Error(msg) => stringContains(msg, "at least one column")->isTruthy
  }
})

test("OptionsParser.parseTableOptions returns Error for column missing name", () => {
  let field = TestHelpers.objectFromJsonString(
    "{\"tableOptions\":{\"columns\":[{\"selector\":\"td\"}]}}",
  )
  switch OptionsParser.parseTableOptions(field) {
  | Ok(_) => failWith("Expected Error for column missing name")
  | Error(msg) => stringContains(msg, "name")->isTruthy
  }
})

test("OptionsParser.parseTableOptions returns Error for column missing selector", () => {
  let field = TestHelpers.objectFromJsonString(
    "{\"tableOptions\":{\"columns\":[{\"name\":\"cell\"}]}}",
  )
  switch OptionsParser.parseTableOptions(field) {
  | Ok(_) => failWith("Expected Error for column missing selector")
  | Error(msg) => stringContains(msg, "selector")->isTruthy
  }
})

test("OptionsParser.parseTableOptions returns Error for unknown column type", () => {
  let field = TestHelpers.objectFromJsonString(
    "{\"tableOptions\":{\"columns\":[{\"name\":\"cell\",\"selector\":\"td\",\"type\":\"unknownType\"}]}}",
  )
  switch OptionsParser.parseTableOptions(field) {
  | Ok(_) => failWith("Expected Error for unknown column type")
  | Error(msg) => stringContains(msg, "Unknown column type")->isTruthy
  }
})

test("OptionsParser.parseTableOptions returns Error for count column type", () => {
  let field = TestHelpers.objectFromJsonString(
    "{\"tableOptions\":{\"columns\":[{\"name\":\"cell\",\"selector\":\"td\",\"type\":\"count\"}]}}",
  )
  switch OptionsParser.parseTableOptions(field) {
  | Ok(_) => failWith("Expected Error for count column type")
  | Error(msg) => stringContains(msg, "count")->isTruthy
  }
})

test("OptionsParser.parseTableOptions returns Error for nested table columns", () => {
  let field = TestHelpers.objectFromJsonString(
    "{\"tableOptions\":{\"columns\":[{\"name\":\"cell\",\"selector\":\"td\",\"type\":\"table\"}]}}",
  )
  switch OptionsParser.parseTableOptions(field) {
  | Ok(_) => failWith("Expected Error for nested table type")
  | Error(msg) => stringContains(msg, "nested table")->isTruthy
  }
})

test("OptionsParser.parseTableOptions returns Error for attribute column without attribute key", () => {
  let field = TestHelpers.objectFromJsonString(
    "{\"tableOptions\":{\"columns\":[{\"name\":\"cell\",\"selector\":\"td\",\"type\":\"attribute\"}]}}",
  )
  switch OptionsParser.parseTableOptions(field) {
  | Ok(_) => failWith("Expected Error for attribute without attribute key")
  | Error(msg) => stringContains(msg, "attribute")->isTruthy
  }
})
