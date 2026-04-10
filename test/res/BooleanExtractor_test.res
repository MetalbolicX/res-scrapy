open Test
open Assertions
open FieldTypes

let getElement = (doc, selector) =>
  switch HtmlFixture.select(doc, selector) {
  | Some(el) => el
  | None => {
      failWith(`Missing element for selector ${selector}`)
      doc
    }
  }

let isExtractionError = value =>
  switch value {
  | ExtractionError(_) => true
  | _ => false
  }

let expectOk = result =>
  switch result {
  | Ok(v) => v
  | Error(_) => {
      failWith("Expected Ok result")
      None
    }
  }

test("BooleanExtractor mapping mode handles defaults", () => {
  let doc = HtmlFixture.parse("<div class='t'>true</div><div class='f'>out of stock</div>")
  let t = getElement(doc, ".t")
  let f = getElement(doc, ".f")
  isOptionEqualTo(Some(true), expectOk(BooleanExtractor.extract(t, None)), ~eq=(a, b) => a == b)
  isOptionEqualTo(Some(false), expectOk(BooleanExtractor.extract(f, None)), ~eq=(a, b) => a == b)
})

test("BooleanExtractor mapping is case insensitive", () => {
  let doc = HtmlFixture.parse("<div class='v'>YES</div>")
  let el = getElement(doc, ".v")
  let opts = Some({trueValues: ["yes"], falseValues: ["no"]})
  isOptionEqualTo(Some(true), expectOk(BooleanExtractor.extract(el, opts)), ~eq=(a, b) => a == b)
})

test("BooleanExtractor handles onUnknown policies", () => {
  let doc = HtmlFixture.parse("<div class='v'>maybe</div>")
  let el = getElement(doc, ".v")

  isOptionEqualTo(
    Some(false),
    expectOk(BooleanExtractor.extract(el, Some({onUnknown: UnknownFalse}))),
    ~eq=(a, b) => a == b,
  )
  isOptionEqualTo(
    None,
    expectOk(BooleanExtractor.extract(el, Some({onUnknown: UnknownNull}))),
    ~eq=(a, b) => a == b,
  )

  switch BooleanExtractor.extract(el, Some({onUnknown: UnknownError})) {
  | Error(e) => isTruthy(isExtractionError(e))
  | Ok(_) => failWith("Expected UnknownError policy to return Error")
  }
})

test("BooleanExtractor attributeCheck mode", () => {
  let doc = HtmlFixture.parse(
    "<div class='a' data-stock='yes'></div><div class='b' data-stock=''></div><div class='c'></div>",
  )
  let a = getElement(doc, ".a")
  let b = getElement(doc, ".b")
  let c = getElement(doc, ".c")
  let opts = Some({mode: AttributeCheck, attribute: "data-stock"})

  isOptionEqualTo(Some(true), expectOk(BooleanExtractor.extract(a, opts)), ~eq=(a, b) => a == b)
  isOptionEqualTo(Some(false), expectOk(BooleanExtractor.extract(b, opts)), ~eq=(a, b) => a == b)
  isOptionEqualTo(Some(false), expectOk(BooleanExtractor.extract(c, opts)), ~eq=(a, b) => a == b)
})
