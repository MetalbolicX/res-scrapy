/**
 * Fast-path `querySelectorAll` for plain `.class`, `#id`, and `tag` selectors.
 *
 * node-html-parser 9.x routes every query through a vendored `findAll` that
 * copies the accumulator at every visited node, which is quadratic in the
 * number of matching siblings (profiled 2026-10-27: ~3.8 s of a 4.5 s
 * `querySelectorAll` on 20k items). The binding now walks the tree once for
 * simple selectors and falls back to the library for everything else. These
 * tests pin two things: the fast path returns exactly what the library
 * returns (same elements, same order, same case-sensitivity), and the walk
 * stays linear (a generous timing-ratio guard that still separates linear
 * scaling from the quadratic baseline it replaced).
 *
 * Differential evidence (2026-10-27, commit 552c650): outputs byte-identical
 * to the pre-change build for the 5k/10k/20k-item benchmark inputs.
 */
open Test
open Assertions
open NodeHtmlParserBinding

/** The library's own `querySelectorAll`, bypassing the binding wrapper, so
    every selector can be compared against the fast path. */
@send external libQuerySelectorAll: (htmlElement, string) => array<htmlElement> = "querySelectorAll"

let html = `<div id="top" class="wrap"><ul><li class="item first" id="one">one</li><li class="item">two</li><li class="Item" id="third">three</li></ul><p class="item">para</p></div>`

let signatures = (elements: array<htmlElement>): string =>
  elements->Belt.Array.map(el => el.outerHTML)->Array.join("|")

// Parity: the fast path must return the same elements in the same order as
// the library for every selector, simple (fast path) or compound (fallback).
[
  (".item", 3),
  (".first", 1),
  (".Item", 1),
  ("#one", 1),
  ("#third", 1),
  ("li", 3),
  ("p", 1),
  ("div", 1),
  ("li.item", 2),
  ("ul > li", 3),
  ("*", 6),
]->Array.forEach(((selector, expectedCount)) => {
  test(`fast select parity: ${selector}`, () => {
    let doc = parse(html)
    let fast = querySelectorAll(doc, selector)
    let lib = libQuerySelectorAll(doc, selector)
    isIntEqualTo(expectedCount, fast->Array.length)
    isTextEqualTo(signatures(lib), signatures(fast))
  })
})

// xmlMode semantics: tag selectors match the lower-cased rawTagName exactly,
// so an upper-cased selector matches nothing. Pin the fast path agrees.
test("fast select tag is case-sensitive like the xmlMode library path", () => {
  let doc = parse(html)
  isIntEqualTo(0, querySelectorAll(doc, "LI")->Array.length)
  isIntEqualTo(3, querySelectorAll(doc, "li")->Array.length)
})

// Text and comment nodes never match; only elements (nodeType 1) are tested.
test("fast select skips text and comment nodes", () => {
  let doc = parse(`<ul> leading <li class="item">x</li> between <li class="item">y</li> end </ul>`)
  isIntEqualTo(2, querySelectorAll(doc, ".item")->Array.length)
})

// A compound or unsupported selector falls back to the library unchanged.
test("fast select falls back to the library for compound selectors", () => {
  let doc = parse(html)
  isIntEqualTo(2, querySelectorAll(doc, "li.item")->Array.length)
  isIntEqualTo(1, querySelectorAll(doc, "li#one")->Array.length)
})

// Regression guard: linear scaling. The quadratic baseline measured 29×
// (4,394 ms at 20k vs 152 ms at 5k); the fast path sits near 4×, so 8× keeps
// real headroom for machine load while still failing a quadratic regression.
let buildFixture: int => string = count => {
  let items = Belt.Array.mapWithIndex(Belt.Array.make(count, 0), (i, _) =>
    `<li class="item">item number ${i->Int.toString}</li>`
  )
  ["<ul>"]->Array.concat(items)->Array.concat(["</ul>"])->Array.join("")
}

test("fast select stays linear in matching siblings", () => {
  let timed = (n: int): float => {
    let doc = parse(buildFixture(n))
    let t0 = NodePerformance.now()
    let matches = querySelectorAll(doc, ".item")
    let t1 = NodePerformance.now()
    let acc = matches->Belt.Array.reduce(0, (sum, el) => sum + String.length(el.textContent))
    let _ = acc
    t1 -. t0
  }
  let t5k = timed(5000)
  let t20k = timed(20000)
  isTruthy(
    t20k < t5k *. 8.0,
    ~message=`20k query took ${t20k->Float.toString}ms vs ${t5k->Float.toString}ms at 5k (limit 8x)`,
  )
})
