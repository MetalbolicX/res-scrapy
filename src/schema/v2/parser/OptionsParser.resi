open FieldTypes

let parseTextOptions: {..} => option<textOptions>
let parseHtmlOptions: {..} => option<htmlOptions>
let parseAttributeConfig: {..} => option<attributeConfig>
let parseErrorPolicy: string => errorPolicy
let parseBooleanUnknownPolicy: string => booleanUnknownPolicy
let parseNumberOptions: {..} => option<numberOptions>
let parseNumberOptionsResult: {..} => result<option<numberOptions>, string>
let parseBooleanOptions: {..} => option<booleanOptions>
let parseCountOptions: {..} => option<countOptions>
let parseCountOptionsResult: {..} => result<option<countOptions>, string>
let parseUrlOptions: {..} => option<urlOptions>
let parseJsonOptions: {..} => option<jsonOptions>
let parseJsonOptionsResult: {..} => result<option<jsonOptions>, string>
let parseDateOptions: {..} => option<dateOptions>
let parseDateOptionsResult: {..} => result<option<dateOptions>, string>
let parseListOptions: {..} => listOptions
let parseTableOptions: {..} => result<tableOptions, string>
