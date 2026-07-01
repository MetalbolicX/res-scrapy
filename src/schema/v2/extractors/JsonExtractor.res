/** Extract and parse JSON from an HTML element.
  *
  * Options:
  *   - source: "text" (default) or "attribute" — where to get the JSON string
  *   - attribute: which attribute to read (when source="attribute")
  *   - path: dot-notation path to extract a subset (e.g., "offers.price")
  *   - onError: error policy when JSON is invalid or path fails
  */
open FieldTypes

module Iter = NodeJsBinding.Iter

let getJsonSource: (NodeHtmlParserBinding.htmlElement, option<jsonOptions>) => option<string> = (
  el,
  opts,
) => {
  let source = switch opts {
  | Some(o) => o.source
  | None => None
  }
  switch source {
  | Some("attribute") =>
    let attrName = switch opts {
    | Some(o) => o.attribute
    | None => None
    }
    let attr = switch attrName {
    | Some(a) => a
    | None => "data-json"
    }
    NodeHtmlParserBinding.getAttribute(el, attr)->Nullable.toOption
  | _ =>
    // Default: use textContent
    Some(el.textContent)
  }
}

/* Typed dictGet local to this module: keeps `getPath` JSON.t-typed so the
   `option<JSON.t>` flows directly to the caller without an Obj.magic cast. */
@get_index external dictGetT: (JSON.t, string) => option<JSON.t> = ""
external testAny: 'a => bool = "%is_nullable"

let getPath: (JSON.t, string) => option<JSON.t> = (obj, path) => {
  if path == "" {
    Some(obj)
  } else {
    let keys = String.split(path, ".")
    let current = ref(Some(obj))
    keys->Iter.values->Iter.forEach(key => {
      switch current.contents {
      | Some(cur) =>
        let val: option<JSON.t> = dictGetT(cur, key)
        switch val {
        | Some(v) =>
          if testAny(v) {
            current := None
          } else {
            current := Some(v)
          }
        | None => current := None
        }
      | None => ()
      }
    })
    current.contents
  }
}

let extract: (NodeHtmlParserBinding.htmlElement, option<jsonOptions>) => option<JSON.t> = (
  el,
  opts,
) => {
  let raw = getJsonSource(el, opts)

  switch raw {
  | None => None
  | Some(str) =>
    let parsed = NodeJsBinding.jsonParse(str)
    switch parsed {
    | None =>
      // JSON parse failed — apply onError policy
      let onErr = switch opts {
      | Some(o) => o.onError
      | None => None
      }
      switch onErr {
      | Some(ReturnText) => Some(JSON.Encode.string(str))
      | Some(ReturnDefault) => None
      | _ => None // ReturnNull (default)
      }
    | Some(json) =>
      // Parse succeeded — apply path if provided
      let path = switch opts {
      | Some(o) => o.path
      | None => None
      }
      switch path {
      | None => Some(json)
      | Some(p) =>
        let extracted = getPath(json, p)
        switch extracted {
        | None =>
          let onErr = switch opts {
          | Some(o) => o.onError
          | None => None
          }
          switch onErr {
          | Some(ReturnText) => Some(JSON.Encode.string(str))
          | Some(ReturnDefault) => None
          | _ => None
          }
        | Some(v) => Some(v)
        }
      }
    }
  }
}
