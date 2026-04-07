open FieldTypes

// @get_index external dictGet: ({..}, string) => option<'a>
let dictGet: ({..}, string) => option<'a>

let parseTextOptions: {..} => option<textOptions>
let parseHtmlOptions: {..} => option<htmlOptions>
let parseAttributeConfig: {..} => option<attributeConfig>
let parseNumberOptions: {..} => option<numberOptions>
let parseBooleanOptions: {..} => option<booleanOptions>
let parseCountOptions: {..} => option<countOptions>
let parseUrlOptions: {..} => option<urlOptions>
let parseJsonOptions: {..} => option<jsonOptions>
let parseDateOptions: {..} => option<dateOptions>
let parseListOptions: {..} => listOptions
