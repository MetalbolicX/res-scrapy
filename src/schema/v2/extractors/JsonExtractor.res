/** Extract and parse JSON from an HTML element.
  *
  * Options:
  *   - source: "text" (default) or "attribute" — where to get the JSON string
  *   - attribute: which attribute to read (when source="attribute")
  *   - path: dot-notation path to extract a subset (e.g., "offers.price")
  *   - onError: error policy when JSON is invalid or path fails
  */
open FieldTypes

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

let getPath: ('a, string) => option<'a> = %raw(`
  (obj, path) => {
    if (!path) return obj;
    var keys = path.split('.');
    var current = obj;
    for (var i = 0; i < keys.length; i++) {
      if (current == null || typeof current !== 'object') return undefined;
      current = current[keys[i]];
    }
    return current;
  }
`)

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
        | Some(v) => Some(Obj.magic(v))
        }
      }
    }
  }
}
