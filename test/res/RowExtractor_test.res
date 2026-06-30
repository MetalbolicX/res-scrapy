open Test
open Assertions
open FieldTypes

test("RowExtractor - Strategy metadata is correct", () => {
  isTextEqualTo("row", RowExtractor.Strategy.name)

  let schemaNoRow: schema = {
    fields: [],
    config: {
      limit: 0,
      ignoreErrors: false,
    },
  }

  let schemaWithRow: schema = {
    fields: [],
    config: {
      rowSelector: ".row",
      limit: 0,
      ignoreErrors: false,
    },
  }

  isTruthy(RowExtractor.Strategy.canHandle(schemaNoRow) == false)
  isTruthy(RowExtractor.Strategy.canHandle(schemaWithRow) == true)
})

test("RowExtractor - run with empty fields returns array of empty objects for each row", () => {
  let doc = HtmlFixture.parse("<div class='r'>A</div><div class='r'>B</div>")
  let schema: schema = {
    fields: [],
    config: {
      rowSelector: ".r",
      limit: 0,
      ignoreErrors: false,
    },
  }

  let result = RowExtractor.run(doc, schema)
  isResultOk(result)
  switch result {
  | Ok(json) => isTextEqualTo("[{},{}]", NodeJsBinding.jsonStringify(json))
  | Error(_) => failWith("Expected array of empty objects")
  }
})

test("RowExtractor handles 100 rows x 10 fields without regression", () => {
  let makeFieldDef = (j): (string, schemaField) => {
    let fd: schemaField = {
      fieldType: Text(None),
      selector: ".f" ++ Int.toString(j),
      required: false,
    }
    ("field" ++ Int.toString(j), fd)
  }
  let fieldDefs = [
    makeFieldDef(1),
    makeFieldDef(2),
    makeFieldDef(3),
    makeFieldDef(4),
    makeFieldDef(5),
    makeFieldDef(6),
    makeFieldDef(7),
    makeFieldDef(8),
    makeFieldDef(9),
    makeFieldDef(10),
  ]

  let doc = HtmlFixture.parse("<div>" ++ {
    let rowTpl = i => "<div class=\"row\">" ++ {
      let cell = j => "<span class=\"f" ++ Int.toString(j) ++ "\">v" ++ Int.toString(i * j) ++ "</span>"
      cell(1) ++ cell(2) ++ cell(3) ++ cell(4) ++ cell(5) ++ cell(6) ++ cell(7) ++ cell(8) ++ cell(9) ++ cell(10)
    } ++ "</div>"
    rowTpl(1) ++ rowTpl(2) ++ rowTpl(3) ++ rowTpl(4) ++ rowTpl(5) ++
    rowTpl(6) ++ rowTpl(7) ++ rowTpl(8) ++ rowTpl(9) ++ rowTpl(10) ++
    rowTpl(11) ++ rowTpl(12) ++ rowTpl(13) ++ rowTpl(14) ++ rowTpl(15) ++
    rowTpl(16) ++ rowTpl(17) ++ rowTpl(18) ++ rowTpl(19) ++ rowTpl(20) ++
    rowTpl(21) ++ rowTpl(22) ++ rowTpl(23) ++ rowTpl(24) ++ rowTpl(25) ++
    rowTpl(26) ++ rowTpl(27) ++ rowTpl(28) ++ rowTpl(29) ++ rowTpl(30) ++
    rowTpl(31) ++ rowTpl(32) ++ rowTpl(33) ++ rowTpl(34) ++ rowTpl(35) ++
    rowTpl(36) ++ rowTpl(37) ++ rowTpl(38) ++ rowTpl(39) ++ rowTpl(40) ++
    rowTpl(41) ++ rowTpl(42) ++ rowTpl(43) ++ rowTpl(44) ++ rowTpl(45) ++
    rowTpl(46) ++ rowTpl(47) ++ rowTpl(48) ++ rowTpl(49) ++ rowTpl(50) ++
    rowTpl(51) ++ rowTpl(52) ++ rowTpl(53) ++ rowTpl(54) ++ rowTpl(55) ++
    rowTpl(56) ++ rowTpl(57) ++ rowTpl(58) ++ rowTpl(59) ++ rowTpl(60) ++
    rowTpl(61) ++ rowTpl(62) ++ rowTpl(63) ++ rowTpl(64) ++ rowTpl(65) ++
    rowTpl(66) ++ rowTpl(67) ++ rowTpl(68) ++ rowTpl(69) ++ rowTpl(70) ++
    rowTpl(71) ++ rowTpl(72) ++ rowTpl(73) ++ rowTpl(74) ++ rowTpl(75) ++
    rowTpl(76) ++ rowTpl(77) ++ rowTpl(78) ++ rowTpl(79) ++ rowTpl(80) ++
    rowTpl(81) ++ rowTpl(82) ++ rowTpl(83) ++ rowTpl(84) ++ rowTpl(85) ++
    rowTpl(86) ++ rowTpl(87) ++ rowTpl(88) ++ rowTpl(89) ++ rowTpl(90) ++
    rowTpl(91) ++ rowTpl(92) ++ rowTpl(93) ++ rowTpl(94) ++ rowTpl(95) ++
    rowTpl(96) ++ rowTpl(97) ++ rowTpl(98) ++ rowTpl(99) ++ rowTpl(100)
  } ++ "</div>")

  let schema: schema = {
    fields: fieldDefs,
    config: {
      rowSelector: ".row",
      limit: 0,
      ignoreErrors: false,
    },
  }

  let result = RowExtractor.run(doc, schema)
  isResultOk(result)
  switch result {
  | Ok(json) => {
      let arr = NodeJsBinding.jsonParse(NodeJsBinding.jsonStringify(json))
      let count = switch arr {
      | Some(JSON.Array(a)) => Array.length(a)
      | _ => 0
      }
      isIntEqualTo(100, count)
    }
  | Error(_) => failWith("RowExtractor should handle 100x10 without error")
  }
})
