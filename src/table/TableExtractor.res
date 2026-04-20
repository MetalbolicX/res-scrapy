/**
  * Extracts an HTML `<table>` element as a JSON-serialisable array of row objects.
  *
  * Each row object maps column header text (from `<th>` cells) to the corresponding
  * `<td>` cell text for that row.  Empty or missing `<th>` text falls back to a
  * positional key `"col_N"` (0-indexed).
  *
  * Header resolution order:
  *   1. `<thead> <th>` cells inside the targeted table.
  *   2. `<th>` cells in the first `<tr>` of the table when no `<thead>` is present.
  *
  * Row resolution order:
  *   1. `<tbody> <tr>` rows inside the targeted table.
  *   2. All `<tr>` rows except the first one when no `<tbody>` is present (that first
  *      row is assumed to be the header row).
  *
  * Missing `<td>` cells in a row are filled with an empty string `""`.
  * Extra `<td>` cells beyond the number of headers are ignored.
  *
  * `colspan`/`rowspan` are treated as plain cells (out of scope for MVP).
 */

/**
  * Extracts the table matching `selector` from `document` and returns an array of
  * row objects, or an error string when no table is found.
 */
module Iter = NodeJsBinding.Iter

let extract: (
  NodeHtmlParserBinding.htmlElement,
  string,
) => result<array<dict<string>>, string> = (document, selector) => {
  switch document->NodeHtmlParserBinding.querySelector(selector)->Nullable.toOption {
  | None => Error(`No element found for table selector "${selector}"`)
  | Some(table) => {
      // -----------------------------------------------------------------------
      // 1. Resolve headers
      // -----------------------------------------------------------------------
      let headerEls: array<NodeHtmlParserBinding.htmlElement> = {
        let fromThead = table->NodeHtmlParserBinding.querySelectorAll("thead th")
        if Array.length(fromThead) > 0 {
          fromThead
        } else {
          // No <thead> — take <th> cells from the very first <tr>
          switch table
          ->NodeHtmlParserBinding.querySelector("tr")
          ->Nullable.toOption {
          | None => []
          | Some(firstRow) => firstRow->NodeHtmlParserBinding.querySelectorAll("th")
          }
        }
      }

      let headers: array<string> =
        headerEls
        ->Iter.entries
        ->Iter.map(((i, el)) => {
          let text = String.trim(el.textContent)
          text == "" ? `col_${Int.toString(i)}` : text
        })
        ->Iter.toArray

      // -----------------------------------------------------------------------
      // 2. Resolve data rows
      // -----------------------------------------------------------------------
      let rowEls: array<NodeHtmlParserBinding.htmlElement> = {
        let fromTbody = table->NodeHtmlParserBinding.querySelectorAll("tbody tr")
        if Array.length(fromTbody) > 0 {
          fromTbody
        } else {
          // No <tbody> — take all <tr>s and skip the first (header) row
          let allRows = table->NodeHtmlParserBinding.querySelectorAll("tr")
          Array.slice(allRows, ~start=1, ~end=Array.length(allRows))
        }
      }

      // -----------------------------------------------------------------------
      // 3. Build row objects
      // -----------------------------------------------------------------------
      let rows: array<dict<string>> =
        rowEls
        ->Iter.values
        ->Iter.map(row => {
          let cells = row->NodeHtmlParserBinding.querySelectorAll("td")
          let obj = Dict.make()
          headers->Iter.entries->Iter.forEach(((i, header)) => {
            let value = switch cells->Array.get(i) {
            | None => ""
            | Some(cell) => String.trim(cell.textContent)
            }
            Dict.set(obj, header, value)
          })
          obj
        })
        ->Iter.toArray

      Ok(rows)
    }
  }
}
