open Test
open Assertions
open FieldTypes

test("null rowSelector parses as absent", () => {
  switch SchemaParser.parseSchema(
    TestHelpers.objectFromJsonString(`{"fields":{"i":{"selector":"i"}},"config":{"rowSelector":null,"limit":null}}`),
  ) {
  | Ok(schema) => {
      isOptionEqualTo(None, schema.config.rowSelector, ~eq=(a, b) => a == b)
      isIntEqualTo(0, schema.config.limit)
    }
  | Error(_) => failWith("Expected schema")
  }
})

test("count defaults reject exact messages including null and min precedence", () => {
  [
    ("{\"min\":1}", "min"),
    ("{\"max\":2}", "max"),
    ("{\"min\":null}", "min"),
    ("{\"max\":null}", "max"),
    ("{\"min\":null,\"max\":2}", "min"),
  ]->Array.forEach(((opts, key)) => {
    let raw = TestHelpers.objectFromJsonString(
      `{"fields":{"n":{"selector":"i","type":"count"}},"config":{"defaults":{"count":${opts}}}}`,
    )
    switch SchemaParser.parseSchema(raw) {
    | Error(InvalidJson(msg)) =>
      isTextEqualTo(
        `config.defaults.count.${key} is accepted but not implemented; this build rejects it instead of silently ignoring it`,
        msg,
      )
    | _ => failWith("Expected InvalidJson for count defaults constraint")
    }
  })
  switch SchemaParser.parseSchema(
    TestHelpers.objectFromJsonString(`{"fields":{"n":{"selector":"i","type":"count"}},"config":{"defaults":{"count":{}}}}`),
  ) {
  | Ok(_) => isTruthy(true)
  | Error(_) => failWith("Empty count defaults rejected")
  }
})

test("ConfigParser.parseConfig uses default config when missing", () => {
  let raw = TestHelpers.objectFromJsonString("{}")
  let config = ConfigParser.parseConfig(raw)
  isTruthy(config.ignoreErrors == false)
  isIntEqualTo(0, config.limit)
  isOptionEqualTo(None, config.rowSelector, ~eq=(a, b) => a == b)
})

test("ConfigParser.parseConfig parses top-level knobs", () => {
  let raw = TestHelpers.objectFromJsonString(
    "{\"config\":{\"ignoreErrors\":true,\"limit\":5,\"rowSelector\":\".row\"}}",
  )
  let config = ConfigParser.parseConfig(raw)
  isTruthy(config.ignoreErrors)
  isIntEqualTo(5, config.limit)
  isOptionEqualTo(Some(".row"), config.rowSelector, ~eq=(a, b) => a == b)
})

test("ConfigParser rejects invalid config.limit values", () => {
  let invalidLimits = ["-1", "1.5", "\"0\""]
  invalidLimits->Array.forEach(limitJson => {
    let schemaJson = `{"fields":{"item":{"selector":".x"}},"config":{"limit":${limitJson}}}`
    switch SchemaParser.parseSchema(TestHelpers.objectFromJsonString(schemaJson)) {
    | Error(InvalidJson(msg)) => isTruthy(String.includes(msg, "config.limit"))
    | Error(_) => failWith("Expected InvalidJson for invalid config.limit")
    | Ok(_) => failWith("Expected invalid config.limit to be rejected")
    }
  })

  let validLimits = [("0", 0), ("5", 5), ("null", 0)]
  validLimits->Array.forEach(((limitJson, expected)) => {
    let schemaJson = `{"fields":{"item":{"selector":".x"}},"config":{"limit":${limitJson}}}`
    switch SchemaParser.parseSchema(TestHelpers.objectFromJsonString(schemaJson)) {
    | Ok(schema) => isIntEqualTo(expected, schema.config.limit)
    | Error(_) => failWith("Expected valid config.limit to be accepted")
    }
  })
})

test("ConfigParser rejects inert defaults.number.onError", () => {
  let schemaJson = "{\"fields\":{\"item\":{\"selector\":\".x\"}},\"config\":{\"defaults\":{\"number\":{\"onError\":\"returnDefault\"}}}}"
  switch SchemaParser.parseSchema(TestHelpers.objectFromJsonString(schemaJson)) {
  | Error(InvalidJson(msg)) => isTruthy(String.includes(msg, "config.defaults.number.onError"))
  | Error(_) => failWith("Expected InvalidJson naming config.defaults.number.onError")
  | Ok(_) => failWith("Expected inert defaults.number.onError to be rejected")
  }
})

test("ConfigParser rejects inert defaults.date.strict", () => {
  let schemaJson = "{\"fields\":{\"item\":{\"selector\":\".x\"}},\"config\":{\"defaults\":{\"date\":{\"strict\":true}}}}"
  switch SchemaParser.parseSchema(TestHelpers.objectFromJsonString(schemaJson)) {
  | Error(InvalidJson(msg)) => isTruthy(String.includes(msg, "defaults.date.strict"))
  | Error(_) => failWith("Expected InvalidJson naming defaults.date.strict")
  | Ok(_) => failWith("Expected inert defaults.date.strict to be rejected")
  }
})

test("ConfigParser rejects inert defaults.datetime.strict", () => {
  let schemaJson = "{\"fields\":{\"item\":{\"selector\":\".x\"}},\"config\":{\"defaults\":{\"datetime\":{\"strict\":true}}}}"
  switch SchemaParser.parseSchema(TestHelpers.objectFromJsonString(schemaJson)) {
  | Error(InvalidJson(msg)) => isTruthy(String.includes(msg, "defaults.datetime.strict"))
  | Error(_) => failWith("Expected InvalidJson naming defaults.datetime.strict")
  | Ok(_) => failWith("Expected inert defaults.datetime.strict to be rejected")
  }
})

test("ConfigParser.parseConfig parses defaults", () => {
  let raw = TestHelpers.objectFromJsonString(
    "{\"config\":{\"defaults\":{\"text\":{\"trim\":false},\"number\":{\"precision\":2},\"boolean\":{\"mode\":\"presence\"}}}}",
  )
  let config = ConfigParser.parseConfig(raw)
  switch config.defaults {
  | None => failWith("Expected defaults")
  | Some(d) => {
      isTruthy(d.text != None)
      isTruthy(d.number != None)
      isTruthy(d.boolean != None)
    }
  }
})
