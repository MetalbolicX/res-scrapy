/**
 * SelectorExtractor unit tests.
 *
 * `extractElements` is async: Multiple mode yields to the event loop between
 * batches so OS signal handlers can run during large extractions (plan 037).
 * Every test therefore awaits the returned promise through a Promise.then
 * chain, following the suite's testAsync convention.
 */
open Test
open Assertions
open ParseCli

let ctx = AppContext.production
let ops = NodeHtmlDocument.operations

let runExtract = (~doc, ~selector, ~extractMode, ~mode) =>
  SelectorExtractor.extractElements(ctx, doc, selector, extractMode, mode)->Promise.then(result => {
    let outcome = switch result {
    | Ok(arr) => arr
    | Error(msg) => {
        failWith(`Expected Ok but got Error: ${msg}`)
        []
      }
    }
    Promise.resolve((outcome: array<string>))
  })

testAsync("SelectorExtractor Single mode returns one element with Text extract", planned => {
  let doc = Document.parse(ops, "<div class='t'>Hello</div>")
  runExtract(~doc, ~selector=".t", ~extractMode=Text, ~mode=Single)
  ->Promise.then(arr => {
    isIntEqualTo(1, Array.length(arr))
    isTextEqualTo("Hello", arr->Array.get(0)->Option.getOr(""))
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(exn => {
    failWithExn("Single mode Text extract assertions failed", exn)
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("SelectorExtractor Multiple mode returns all matches with Text extract", planned => {
  let doc = Document.parse(ops, "<span>A</span><span>B</span><span>C</span>")
  runExtract(~doc, ~selector="span", ~extractMode=Text, ~mode=Multiple)
  ->Promise.then(arr => {
    isIntEqualTo(3, Array.length(arr))
    isTextEqualTo("A", arr->Array.get(0)->Option.getOr(""))
    isTextEqualTo("B", arr->Array.get(1)->Option.getOr(""))
    isTextEqualTo("C", arr->Array.get(2)->Option.getOr(""))
    planned(~planned=4, ())
    Promise.resolve()
  })
  ->Promise.catch(exn => {
    failWithExn("Multiple mode Text extract assertions failed", exn)
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("SelectorExtractor Single mode with no match returns empty array", planned => {
  let doc = Document.parse(ops, "<div>nope</div>")
  runExtract(~doc, ~selector=".missing", ~extractMode=Text, ~mode=Single)
  ->Promise.then(arr => {
    isIntEqualTo(0, Array.length(arr))
    planned(~planned=1, ())
    Promise.resolve()
  })
  ->Promise.catch(exn => {
    failWithExn("Single no-match assertions failed", exn)
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("SelectorExtractor Multiple mode with no match returns empty array", planned => {
  let doc = Document.parse(ops, "<div>nope</div>")
  runExtract(~doc, ~selector=".missing", ~extractMode=Text, ~mode=Multiple)
  ->Promise.then(arr => {
    isIntEqualTo(0, Array.length(arr))
    planned(~planned=1, ())
    Promise.resolve()
  })
  ->Promise.catch(exn => {
    failWithExn("Multiple no-match assertions failed", exn)
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("SelectorExtractor OuterHtml extract contains the tag", planned => {
  let doc = Document.parse(ops, "<div class='t'>Hello</div>")
  runExtract(~doc, ~selector=".t", ~extractMode=OuterHtml, ~mode=Single)
  ->Promise.then(arr => {
    isIntEqualTo(1, Array.length(arr))
    isTruthy(%raw(`s => s.includes("<div")`)(arr->Array.get(0)->Option.getOr("")))
    isTruthy(%raw(`s => s.includes("Hello")`)(arr->Array.get(0)->Option.getOr("")))
    planned(~planned=3, ())
    Promise.resolve()
  })
  ->Promise.catch(exn => {
    failWithExn("OuterHtml extract assertions failed", exn)
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("SelectorExtractor InnerHtml extract contains inner content", planned => {
  let doc = Document.parse(ops, "<div class='t'>Hello</div>")
  runExtract(~doc, ~selector=".t", ~extractMode=InnerHtml, ~mode=Single)
  ->Promise.then(arr => {
    isIntEqualTo(1, Array.length(arr))
    isTruthy(%raw(`s => s.includes("Hello")`)(arr->Array.get(0)->Option.getOr("")))
    isTruthy(%raw(`s => !s.includes("<div")`)(arr->Array.get(0)->Option.getOr("")))
    planned(~planned=3, ())
    Promise.resolve()
  })
  ->Promise.catch(exn => {
    failWithExn("InnerHtml extract assertions failed", exn)
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("SelectorExtractor Attribute extract returns attribute value", planned => {
  let doc = Document.parse(ops, "<a class='link' href='https://example.com'>x</a>")
  runExtract(~doc, ~selector=".link", ~extractMode=Attribute("href"), ~mode=Single)
  ->Promise.then(arr => {
    isIntEqualTo(1, Array.length(arr))
    isTextEqualTo("https://example.com", arr->Array.get(0)->Option.getOr(""))
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(exn => {
    failWithExn("Attribute extract assertions failed", exn)
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

testAsync("SelectorExtractor missing attribute returns empty string", planned => {
  let doc = Document.parse(ops, "<a class='link'>x</a>")
  runExtract(~doc, ~selector=".link", ~extractMode=Attribute("href"), ~mode=Single)
  ->Promise.then(arr => {
    isIntEqualTo(1, Array.length(arr))
    isTextEqualTo("", arr->Array.get(0)->Option.getOr(""))
    planned(~planned=2, ())
    Promise.resolve()
  })
  ->Promise.catch(exn => {
    failWithExn("Missing attribute assertions failed", exn)
    planned(~planned=0, ())
    Promise.resolve()
  })
  ->ignore
})

// mapInBatches must keep a flat call stack: an await-per-item recursion
// overflows the stack once a batch grows past a few thousand items.
[10_000, 50_000]->Array.forEach(batchSize => {
  testAsync(
    `mapInBatches handles batch size ${batchSize->Int.toString} without stack overflow`,
    planned => {
      let items = Belt.Array.makeBy(100_000, i => i)
      SelectorExtractor.mapInBatches(
        items,
        ~batchSize,
        ~yieldFn=() => Promise.resolve(),
        i => i * 2,
      )
      ->Promise.then(
        out => {
          isIntEqualTo(100_000, Array.length(out))
          isIntEqualTo(199_998, out->Array.get(99_999)->Option.getOr(-1))
          planned(~planned=2, ())
          Promise.resolve()
        },
      )
      ->Promise.catch(
        exn => {
          failWithExn(`mapInBatches batch size ${batchSize->Int.toString} failed`, exn)
          planned(~planned=0, ())
          Promise.resolve()
        },
      )
      ->ignore
    },
  )
})

// It pauses after every full batch, never after the last item, keeps order,
// and yields nothing for an empty input.
[(10, 3, 3), (9, 3, 2), (3, 3, 0), (0, 3, 0)]->Array.forEach(((
  count,
  batchSize,
  expectedYields,
)) => {
  testAsync(
    `mapInBatches yields ${expectedYields->Int.toString} times for ${count->Int.toString} items in batches of ${batchSize->Int.toString}`,
    planned => {
      let yields = ref(0)
      let items = Belt.Array.makeBy(count, i => i)
      SelectorExtractor.mapInBatches(
        items,
        ~batchSize,
        ~yieldFn=() => {
          yields := yields.contents + 1
          Promise.resolve()
        },
        i => i,
      )
      ->Promise.then(
        out => {
          isIntEqualTo(expectedYields, yields.contents)
          isTruthy(out == items, ~message="output order differs from input order")
          planned(~planned=2, ())
          Promise.resolve()
        },
      )
      ->Promise.catch(
        exn => {
          failWithExn("mapInBatches yield-count assertions failed", exn)
          planned(~planned=0, ())
          Promise.resolve()
        },
      )
      ->ignore
    },
  )
})
