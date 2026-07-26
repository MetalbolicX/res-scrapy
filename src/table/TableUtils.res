open NodeHtmlParserBinding

let resolveHeaders: htmlElement => array<htmlElement> = table => {
  let fromThead = table->querySelectorAll("thead th")
  if Array.length(fromThead) > 0 {
    fromThead
  } else {
    switch table->querySelector("tr")->Nullable.toOption {
    | None => []
    | Some(firstRow) => firstRow->querySelectorAll("th")
    }
  }
}

let isFirstRowHeader: htmlElement => bool = table =>
  switch table->querySelector("tr")->Nullable.toOption {
  | None => false
  | Some(firstRow) => Array.length(firstRow->querySelectorAll("th")) > 0
  }

let resolveRows: (htmlElement, option<string>) => array<htmlElement> = (table, rowSelector) => {
  switch rowSelector {
  | Some(sel) => table->querySelectorAll(sel)
  | None => {
      let fromTbody = table->querySelectorAll("tbody tr")
      if Array.length(fromTbody) > 0 {
        fromTbody
      } else {
        let allRows = table->querySelectorAll("tr")
        if Array.length(allRows) <= 1 {
          []
        } else if isFirstRowHeader(table) {
          Array.slice(allRows, ~start=1, ~end=Array.length(allRows))
        } else {
          allRows
        }
      }
    }
  }
}
