/** Extract and normalise a URL from an HTML element.
  *
  * Options:
  *   - attribute: which attribute to read (default: href for <a>, src for <img>, else href)
  *   - base: base URL for resolving relative URLs
  *   - resolve: whether to resolve relative URLs against base (default: true)
  *   - validate: whether to validate URL format (default: true)
  *   - protocol: if set, verify URL uses this protocol (e.g. "https")
  *   - stripQuery: remove query string (default: false)
  *   - stripHash: remove fragment/hash (default: false)
  */
open FieldTypes

let defaultAttribute: string => string = tagName => {
  switch tagName {
  | "A" => "href"
  | "IMG" => "src"
  | "IFRAME" => "src"
  | "SOURCE" => "src"
  | "LINK" => "href"
  | _ => "href"
  }
}

let getUrlAttribute: (NodeHtmlParserBinding.htmlElement, option<string>) => option<string> = (
  el,
  explicitAttr,
) => {
  let attrName = switch explicitAttr {
  | Some(a) => a
  | None => defaultAttribute(el.tagName)
  }
  NodeHtmlParserBinding.getAttribute(el, attrName)->Nullable.toOption
}

let extract: (NodeHtmlParserBinding.htmlElement, option<urlOptions>) => option<string> = (
  el,
  opts,
) => {
  // 1. Get the raw attribute value
  let raw = getUrlAttribute(
    el,
    switch opts {
    | Some(o) => o.attribute
    | None => None
    },
  )

  switch raw {
  | None => None
  | Some(urlStr) =>
    if urlStr === "" {
      None
    } else {
      let shouldResolve = switch opts {
      | Some(o) => o.resolve->Option.getOr(true)
      | None => true
      }
      let shouldValidate = switch opts {
      | Some(o) => o.validate->Option.getOr(true)
      | None => true
      }
      let baseUrl = switch opts {
      | Some(o) => o.base
      | None => None
      }

      // 2. Resolve relative URL if needed
      let resolvedUrl = if shouldResolve && baseUrl->Option.isSome {
        try {
          Some(NodeJsBinding.Url.make(urlStr, baseUrl))
        } catch {
        | _ => None
        }
      } else {
        // Still parse to validate
        try {
          Some(NodeJsBinding.Url.make(urlStr, None))
        } catch {
        | _ => None
        }
      }

      switch resolvedUrl {
      | None if shouldValidate => None
      | Some(url) => {
          // 3. Validate protocol if required
          let protoOk = switch opts {
          | Some(o) =>
            switch o.protocol {
            | None => true
            | Some(p) =>
              let expected = if String.endsWith(p, ":") {
                p
              } else {
                p ++ ":"
              }
              url.protocol === expected
            }
          | None => true
          }
          if !protoOk {
            None
          } else {
            // 4. Build final URL string, stripping query/hash as needed
            let final = ref(url.href)
            if (
              switch opts {
              | Some(o) => o.stripQuery == Some(true)
              | None => false
              }
            ) {
              final := url.href->String.split("?")->Array.get(0)->Option.getOr(final.contents)
            }
            if (
              switch opts {
              | Some(o) => o.stripHash == Some(true)
              | None => false
              }
            ) {
              final := final.contents->String.split("#")->Array.get(0)->Option.getOr(final.contents)
            }
            Some(final.contents)
          }
        }
      | None => None
      }
    }
  }
}
