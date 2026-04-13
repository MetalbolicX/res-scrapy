open FieldTypes

module type Spec = {
  let name: string
  let canHandle: schema => bool
  let run: (NodeHtmlParserBinding.htmlElement, schema) => result<JSON.t, schemaError>
}

module type S = {
  let name: string
  let canHandle: schema => bool
  let execute: (NodeHtmlParserBinding.htmlElement, schema) => result<JSON.t, schemaError>
}

module Make = (Impl: Spec): S => {
  let name = Impl.name
  let canHandle = Impl.canHandle
  let execute = Impl.run
}
