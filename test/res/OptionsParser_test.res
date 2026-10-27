open Test
open Assertions
open TestHelpers
open FieldTypes

test("null list limit is omitted", () => {
  switch OptionsParser.parseListOptions(objectFromJsonString(`{"listOptions":{"limit":null}}`)) {
  | Ok(opts) => isOptionEqualTo(None, opts.limit, ~eq=(a, b) => a == b)
  | Error(msg) => failWith(`Expected null limit to be accepted, got ${msg}`)
  }
})

test("list limit accepts non-negative integers and rejects everything else", () => {
  [("0", 0), ("3", 3)]->Array.forEach(((limitJson, expected)) =>
    switch OptionsParser.parseListOptions(
      objectFromJsonString(`{"listOptions":{"limit":${limitJson}}}`),
    ) {
    | Ok(opts) => isOptionEqualTo(Some(expected), opts.limit, ~eq=(a, b) => a == b)
    | Error(msg) => failWith(`Expected limit ${limitJson} to be accepted, got ${msg}`)
    }
  )
  ["-1", "2.5", "\"2\"", "true", "[]"]->Array.forEach(limitJson =>
    switch OptionsParser.parseListOptions(
      objectFromJsonString(`{"listOptions":{"limit":${limitJson}}}`),
    ) {
    | Ok(_) => failWith(`Expected limit ${limitJson} to be rejected`)
    | Error(msg) =>
      isTextEqualTo(`listOptions.limit must be a non-negative integer, got ${limitJson}`, msg)
    }
  )
})

test("table rowSelector must be a string when present", () => {
  let columns = `"columns":[{"name":"a","selector":"td"}]`
  [("5", "number"), ("[\"tr\"]", "array"), ("{}", "object")]->Array.forEach(((
    rowSelectorJson,
    jsonType,
  )) =>
    switch OptionsParser.parseTableOptions(
      objectFromJsonString(`{"tableOptions":{"rowSelector":${rowSelectorJson},${columns}}}`),
    ) {
    | Ok(_) => failWith(`Expected rowSelector ${rowSelectorJson} to be rejected`)
    | Error(msg) => isTextEqualTo(`tableOptions.rowSelector must be a string, got ${jsonType}`, msg)
    }
  )
  switch OptionsParser.parseTableOptions(
    objectFromJsonString(`{"tableOptions":{"rowSelector":"tr.data",${columns}}}`),
  ) {
  | Ok(opts) => isOptionEqualTo(Some("tr.data"), opts.rowSelector, ~eq=(a, b) => a == b)
  | Error(msg) => failWith(`Expected string rowSelector to be accepted, got ${msg}`)
  }
})

test("count constraints reject exact field messages including null and min precedence", () => {
  [
    ("{\"min\":1}", "min"),
    ("{\"max\":2}", "max"),
    ("{\"min\":null}", "min"),
    ("{\"max\":null}", "max"),
    ("{\"min\":null,\"max\":2}", "min"),
  ]->Array.forEach(((opts, key)) => {
    let raw = objectFromJsonString(
      `{"fields":{"n":{"selector":"i","type":"count","countOptions":${opts}}}}`,
    )
    switch SchemaParser.parseSchema(raw) {
    | Error(InvalidFieldType({field, got})) => {
        isTextEqualTo("n", field)
        isTextEqualTo(
          `count option ${key} is accepted but not implemented; this build rejects it instead of silently ignoring it`,
          got,
        )
      }
    | _ => failWith("Expected InvalidFieldType for count constraint")
    }
  })
  ["", ",\"countOptions\":{}"]->Array.forEach(options => {
    switch SchemaParser.parseSchema(
      objectFromJsonString(`{"fields":{"n":{"selector":"i","type":"count"${options}}}}`),
    ) {
    | Ok(_) => isTruthy(true)
    | Error(_) => failWith("Supported count rejected")
    }
  })
})

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

test("SchemaParser rejects malformed attributes and accepts supported forms", () => {
  let rejectedSchemas = [
    "{\"fields\":{\"item\":{\"type\":\"attribute\",\"selector\":\".x\",\"attributes\":\"src\"}}}",
    "{\"fields\":{\"item\":{\"type\":\"attribute\",\"selector\":\".x\",\"attributes\":[\"href\",42]}}}",
    "{\"fields\":{\"item\":{\"type\":\"attribute\",\"selector\":\".x\",\"attributes\":[]}}}",
  ]
  rejectedSchemas->Array.forEach(schemaJson =>
    switch SchemaParser.parseSchema(TestHelpers.objectFromJsonString(schemaJson)) {
    | Error(_) => ()
    | Ok(_) => failWith("Expected malformed attributes to be rejected")
    }
  )

  let validSchemas = [
    "{\"fields\":{\"item\":{\"type\":\"attribute\",\"selector\":\".x\",\"attributes\":[\"href\",\"src\"]}}}",
    "{\"fields\":{\"item\":{\"type\":\"attribute\",\"selector\":\".x\",\"attribute\":\"src\"}}}",
  ]
  validSchemas->Array.forEach(schemaJson =>
    switch SchemaParser.parseSchema(TestHelpers.objectFromJsonString(schemaJson)) {
    | Ok(_) => ()
    | Error(_) => failWith("Expected supported attributes to be accepted")
    }
  )
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
    "{\"numberOptions\":{\"stripNonNumeric\":false,\"precision\":2,\"allowNegative\":false}}",
  )
  switch OptionsParser.parseNumberOptions(field) {
  | Some(opts) => {
      isOptionEqualTo(Some(false), opts.stripNonNumeric, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(2), opts.precision, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(false), opts.allowNegative, ~eq=(a, b) => a == b)
    }
  | None => failWith("Expected number options")
  }
})

test("SchemaParser rejects inert field-level schema options", () => {
  let rejectedSchemas = [
    (
      "{\"fields\":{\"item\":{\"type\":\"number\",\"selector\":\".x\",\"numberOptions\":{\"onError\":\"returnDefault\"}}}}",
      "number option onError",
    ),
    (
      "{\"fields\":{\"item\":{\"type\":\"datetime\",\"selector\":\".x\",\"dateOptions\":{\"strict\":true}}}}",
      "date option strict",
    ),
    (
      "{\"fields\":{\"item\":{\"type\":\"json\",\"selector\":\".x\",\"jsonOptions\":{\"onError\":\"returnDefault\"}}}}",
      "json option onError",
    ),
  ]
  rejectedSchemas->Array.forEach(((schemaJson, expectedMessage)) =>
    switch SchemaParser.parseSchema(TestHelpers.objectFromJsonString(schemaJson)) {
    | Error(InvalidFieldType({got, _})) => isTruthy(String.includes(got, expectedMessage))
    | Error(_) => failWith(`Expected InvalidFieldType naming ${expectedMessage}`)
    | Ok(_) => failWith(`Expected ${expectedMessage} to be rejected`)
    }
  )
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

test("OptionsParser.parseHtmlOptions returns None when mode is absent", () => {
  let field = TestHelpers.objectFromJsonString("{\"htmlOptions\":{}}")
  switch OptionsParser.parseHtmlOptions(field) {
  | Some(_) => failWith("Expected None for absent mode")
  | None => () // correct
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
    "{\"jsonOptions\":{\"source\":\"attribute\",\"attribute\":\"data-json\",\"path\":\"item.price\"}}",
  )
  switch OptionsParser.parseJsonOptions(field) {
  | Some(opts) => {
      isOptionEqualTo(Some("attribute"), opts.source, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some("data-json"), opts.attribute, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some("item.price"), opts.path, ~eq=(a, b) => a == b)
    }
  | None => failWith("Expected json options")
  }
})

test("OptionsParser.parseDateOptions parses output source and attribute", () => {
  let field = TestHelpers.objectFromJsonString(
    "{\"dateOptions\":{\"formats\":[\"yyyy-MM-dd\",\"ISO\"],\"timezone\":\"UTC\",\"output\":\"custom\",\"outputFormat\":\"MM/dd/yyyy\",\"source\":\"attribute\",\"attribute\":\"datetime\"}}",
  )
  switch OptionsParser.parseDateOptions(field) {
  | Some(opts) => {
      isOptionEqualTo(Some("UTC"), opts.timezone, ~eq=(a, b) => a == b)
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
  let opts = switch OptionsParser.parseListOptions(field) {
  | Ok(opts) => opts
  | Error(msg) => {
      failWith(`Expected list options to parse, got ${msg}`)
      {itemType: ListText}
    }
  }
  switch opts.itemType {
  | ListAttribute(name) => isTextEqualTo("data-id", name)
  | _ => failWith("Expected ListAttribute itemType")
  }
  isOptionEqualTo(Some(true), opts.unique, ~eq=(a, b) => a == b)
  isOptionEqualTo(Some("^a"), opts.filter, ~eq=(a, b) => a == b)
  isOptionEqualTo(Some(3), opts.limit, ~eq=(a, b) => a == b)
  isOptionEqualTo(Some(","), opts.join, ~eq=(a, b) => a == b)
})

test("OptionsParser.parseTableOptions rejects malformed column shapes", () => {
  let invalidColumns = [
    "{\"fields\":{\"items\":{\"type\":\"table\",\"selector\":\".x\",\"tableOptions\":{\"columns\":{}}}}}",
    "{\"fields\":{\"items\":{\"type\":\"table\",\"selector\":\".x\",\"tableOptions\":{\"columns\":[null]}}}}",
  ]
  invalidColumns->Array.forEach(schemaJson =>
    switch SchemaParser.parseSchema(TestHelpers.objectFromJsonString(schemaJson)) {
    | Error(_) => ()
    | Ok(_) => failWith("Expected malformed columns to be rejected")
    }
  )

  let validColumns = TestHelpers.objectFromJsonString(
    "{\"fields\":{\"items\":{\"type\":\"table\",\"selector\":\".x\",\"tableOptions\":{\"columns\":[{\"name\":\"title\",\"selector\":\"td\"}]}}}}",
  )
  switch SchemaParser.parseSchema(validColumns) {
  | Ok(_) => ()
  | Error(_) => failWith("Expected valid columns to be accepted")
  }
})

test("OptionsParser.parseTableOptions rejects inert column options", () => {
  let rejectedColumns = [
    (
      "{\"tableOptions\":{\"columns\":[{\"name\":\"price\",\"selector\":\"td\",\"type\":\"number\",\"numberOptions\":{\"onError\":\"returnText\"}}]}}",
      "number option onError",
    ),
    (
      "{\"tableOptions\":{\"columns\":[{\"name\":\"payload\",\"selector\":\"td\",\"type\":\"json\",\"jsonOptions\":{\"onError\":\"returnText\"}}]}}",
      "json option onError",
    ),
    (
      "{\"tableOptions\":{\"columns\":[{\"name\":\"date\",\"selector\":\"td\",\"type\":\"datetime\",\"dateOptions\":{\"strict\":true}}]}}",
      "date option strict",
    ),
  ]
  rejectedColumns->Array.forEach(((columnConfig, expectedMessage)) =>
    switch OptionsParser.parseTableOptions(TestHelpers.objectFromJsonString(columnConfig)) {
    | Ok(_) => failWith(`Expected column option to be rejected: ${expectedMessage}`)
    | Error(msg) => stringContains(msg, expectedMessage)->isTruthy
    }
  )
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

test(
  "OptionsParser.parseTableOptions returns Error for attribute column without attribute key",
  () => {
    let field = TestHelpers.objectFromJsonString(
      "{\"tableOptions\":{\"columns\":[{\"name\":\"cell\",\"selector\":\"td\",\"type\":\"attribute\"}]}}",
    )
    switch OptionsParser.parseTableOptions(field) {
    | Ok(_) => failWith("Expected Error for attribute without attribute key")
    | Error(msg) => stringContains(msg, "attribute")->isTruthy
    }
  },
)

/* -------------------------------------------------------------------------- */
/* Shared Option Parsing — after the refactor, OptionsParser and */
/* ConfigParser MUST produce structurally identical textOptions from the same */
/* raw JSON. These tests pin that contract before OptionFields.res exists. */
/* -------------------------------------------------------------------------- */

test("OptionsParser and ConfigParser produce identical textOptions (full payload)", () => {
  let textJson = "{\"trim\":false,\"normalizeWhitespace\":true,\"lowercase\":true,\"uppercase\":false,\"pattern\":\"([0-9]+)\",\"join\":\",\"}"

  let fromOptions =
    TestHelpers.objectFromJsonString(`{"textOptions":${textJson}}`)->OptionsParser.parseTextOptions

  /* ConfigParser side: parsed via parseConfig which exposes the text defaults. */
  let fromConfigRaw = TestHelpers.objectFromJsonString(
    `{"config":{"defaults":{"text":${textJson}}}}`,
  )
  let fromConfig = ConfigParser.parseConfig(fromConfigRaw)

  switch fromOptions {
  | Some(opts) =>
    switch fromConfig.defaults {
    | Some(d) =>
      switch d.text {
      | Some(dText) => {
          isOptionEqualTo(opts.trim, dText.trim, ~eq=(a, b) => a == b)
          isOptionEqualTo(opts.normalizeWhitespace, dText.normalizeWhitespace, ~eq=(a, b) => a == b)
          isOptionEqualTo(opts.lowercase, dText.lowercase, ~eq=(a, b) => a == b)
          isOptionEqualTo(opts.uppercase, dText.uppercase, ~eq=(a, b) => a == b)
          isOptionEqualTo(opts.pattern, dText.pattern, ~eq=(a, b) => a == b)
          isOptionEqualTo(opts.join, dText.join, ~eq=(a, b) => a == b)
        }
      | None => failWith("Expected text defaults to be parsed")
      }
    | None => failWith("Expected defaults block")
    }
  | None => failWith("Expected OptionsParser to produce Some(textOptions)")
  }
})

test("OptionsParser and ConfigParser produce identical textOptions (sparse payload)", () => {
  let textJson = "{\"trim\":true}"

  let fromOptions =
    TestHelpers.objectFromJsonString(`{"textOptions":${textJson}}`)->OptionsParser.parseTextOptions

  let fromConfigRaw = TestHelpers.objectFromJsonString(
    `{"config":{"defaults":{"text":${textJson}}}}`,
  )
  let fromConfig = ConfigParser.parseConfig(fromConfigRaw)

  switch fromOptions {
  | Some(opts) =>
    switch fromConfig.defaults {
    | Some(d) =>
      switch d.text {
      | Some(dText) => {
          isOptionEqualTo(Some(true), opts.trim, ~eq=(a, b) => a == b)
          isOptionEqualTo(opts.trim, dText.trim, ~eq=(a, b) => a == b)
          isOptionEqualTo(opts.normalizeWhitespace, dText.normalizeWhitespace, ~eq=(a, b) => a == b)
          isOptionEqualTo(opts.lowercase, dText.lowercase, ~eq=(a, b) => a == b)
          isOptionEqualTo(opts.uppercase, dText.uppercase, ~eq=(a, b) => a == b)
          isOptionEqualTo(opts.pattern, dText.pattern, ~eq=(a, b) => a == b)
          isOptionEqualTo(opts.join, dText.join, ~eq=(a, b) => a == b)
        }
      | None => failWith("Expected text defaults to be parsed")
      }
    | None => failWith("Expected defaults block")
    }
  | None => failWith("Expected OptionsParser to produce Some(textOptions)")
  }
})

test("OptionsParser returns None when textOptions key is absent", () => {
  let field = TestHelpers.objectFromJsonString("{}")
  isOptionEqualTo(None, OptionsParser.parseTextOptions(field), ~eq=(a, b) => a == b)
})

test("ConfigParser with empty text defaults yields all-None text options", () => {
  let fromConfigRaw = TestHelpers.objectFromJsonString(`{"config":{"defaults":{"text":{}}}}`)
  let fromConfig = ConfigParser.parseConfig(fromConfigRaw)
  switch fromConfig.defaults {
  | Some(d) =>
    switch d.text {
    | Some(dText) => {
        isOptionEqualTo(None, dText.trim, ~eq=(a, b) => a == b)
        isOptionEqualTo(None, dText.normalizeWhitespace, ~eq=(a, b) => a == b)
        isOptionEqualTo(None, dText.lowercase, ~eq=(a, b) => a == b)
        isOptionEqualTo(None, dText.uppercase, ~eq=(a, b) => a == b)
        isOptionEqualTo(None, dText.pattern, ~eq=(a, b) => a == b)
        isOptionEqualTo(None, dText.join, ~eq=(a, b) => a == b)
      }
    | None => failWith("Expected text defaults to be present")
    }
  | None => failWith("Expected defaults block")
  }
})
