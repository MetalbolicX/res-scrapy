open Test
open Assertions
open FieldTypes

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

test("ConfigParser.parseConfig parses defaults section with text, number, boolean", () => {
  let raw = TestHelpers.objectFromJsonString(
    "{\"config\":{\"defaults\":{\"text\":{\"trim\":false,\"lowercase\":true},\"number\":{\"precision\":3},\"boolean\":{\"mode\":\"presence\"}}}}",
  )
  let config = ConfigParser.parseConfig(raw)
  switch config.defaults {
  | None => failWith("Expected defaults")
  | Some(d) => {
      switch d.text {
      | None => failWith("Expected text defaults")
      | Some(textOpts) => {
          isOptionEqualTo(Some(false), textOpts.trim, ~eq=(a, b) => a == b)
          isOptionEqualTo(Some(true), textOpts.lowercase, ~eq=(a, b) => a == b)
        }
      }
      switch d.number {
      | None => failWith("Expected number defaults")
      | Some(numOpts) => isOptionEqualTo(Some(3), numOpts.precision, ~eq=(a, b) => a == b)
      }
      switch d.boolean {
      | None => failWith("Expected boolean defaults")
      | Some(boolOpts) => {
          switch boolOpts.mode {
          | Some(Presence) => pass()
          | _ => failWith("Expected presence mode")
          }
        }
      }
    }
  }
})

test("ConfigParser.parseConfig with empty config returns default config", () => {
  let raw = TestHelpers.objectFromJsonString("{\"config\":{}}")
  let config = ConfigParser.parseConfig(raw)
  isTruthy(config.ignoreErrors == false)
  isIntEqualTo(0, config.limit)
})

test("OptionsParser.parseAttributeConfig parses single attribute", () => {
  let field = TestHelpers.objectFromJsonString(
    "{\"attribute\":\"href\",\"attributeOptions\":{\"mode\":\"first\"}}",
  )
  switch OptionsParser.parseAttributeConfig(field) {
  | Some(cfg) => {
      isIntEqualTo(1, Array.length(cfg.names))
      isTruthy(cfg.mode == First)
    }
  | None => failWith("Expected attribute config")
  }
})

test("OptionsParser.parseAttributeConfig parses array attributes with join", () => {
  let field = TestHelpers.objectFromJsonString(
    "{\"attributes\":[\"href\",\"title\"],\"attributeOptions\":{\"mode\":\"join\",\"joinSep\":\", \"}}",
  )
  switch OptionsParser.parseAttributeConfig(field) {
  | Some(cfg) => {
      isIntEqualTo(2, Array.length(cfg.names))
      isTruthy(cfg.mode == Join)
    }
  | None => failWith("Expected attribute config for array mode")
  }
})

test("OptionsParser.parseTextOptions parses options from field object", () => {
  let field = TestHelpers.objectFromJsonString(
    "{\"textOptions\":{\"trim\":false,\"lowercase\":true,\"pattern\":\"[0-9]+\"}}",
  )
  switch OptionsParser.parseTextOptions(field) {
  | Some(opts) => {
      isOptionEqualTo(Some(false), opts.trim, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(true), opts.lowercase, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some("[0-9]+"), opts.pattern, ~eq=(a, b) => a == b)
    }
  | None => failWith("Expected text options")
  }
})

test("OptionsParser.parseNumberOptions returns Some for valid field", () => {
  let field = TestHelpers.objectFromJsonString(
    "{\"numberOptions\":{\"precision\":4,\"allowNegative\":true}}",
  )
  switch OptionsParser.parseNumberOptions(field) {
  | Some(opts) => {
      isOptionEqualTo(Some(4), opts.precision, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(true), opts.allowNegative, ~eq=(a, b) => a == b)
    }
  | None => failWith("Expected number options")
  }
})

test("OptionsParser.parseUrlOptions parses all keys including base and protocol", () => {
  let field = TestHelpers.objectFromJsonString(
    "{\"urlOptions\":{\"base\":\"https://example.com\",\"protocol\":\"https\",\"stripQuery\":true}}",
  )
  switch OptionsParser.parseUrlOptions(field) {
  | Some(opts) => {
      isOptionEqualTo(Some("https://example.com"), opts.base, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some("https"), opts.protocol, ~eq=(a, b) => a == b)
      isOptionEqualTo(Some(true), opts.stripQuery, ~eq=(a, b) => a == b)
    }
  | None => failWith("Expected url options")
  }
})

test("ConfigParser.parseConfig parses boolean defaults with trueValues and falseValues", () => {
  let raw = TestHelpers.objectFromJsonString(
    "{\"config\":{\"defaults\":{\"boolean\":{\"mode\":\"mapping\",\"trueValues\":[\"yes\",\"1\"],\"falseValues\":[\"no\",\"0\"]}}}}",
  )
  let config = ConfigParser.parseConfig(raw)
  switch config.defaults {
  | None => failWith("Expected defaults")
  | Some(d) =>
    switch d.boolean {
    | None => failWith("Expected boolean defaults")
    | Some(boolOpts) => {
        switch boolOpts.mode {
        | Some(Mapping) => pass()
        | _ => failWith("Expected mapping mode")
        }
        let tv = boolOpts.trueValues
        let fv = boolOpts.falseValues
        isTruthy(tv != None && fv != None)
      }
    }
  }
})

test("OptionsParser.parseBooleanOptions parses attributeCheck mode", () => {
  let field = TestHelpers.objectFromJsonString(
    "{\"booleanOptions\":{\"mode\":\"attributeCheck\",\"attribute\":\"data-visible\"}}",
  )
  switch OptionsParser.parseBooleanOptions(field) {
  | Some(opts) => {
      switch opts.mode {
      | Some(AttributeCheck) => pass()
      | _ => failWith("Expected AttributeCheck mode")
      }
      isOptionEqualTo(Some("data-visible"), opts.attribute, ~eq=(a, b) => a == b)
    }
  | None => failWith("Expected boolean options")
  }
})
