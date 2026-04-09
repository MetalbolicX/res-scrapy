open FieldTypes

let parseTextOptions: {..} => option<textOptions>
let parseHtmlOptions: {..} => option<htmlOptions>
let parseAttributeConfig: {..} => option<attributeConfig>
let parseErrorPolicy: string => errorPolicy
let parseBooleanUnknownPolicy: string => booleanUnknownPolicy
let parseNumberOptions: {..} => option<numberOptions>
let parseBooleanOptions: {..} => option<booleanOptions>
let parseCountOptions: {..} => option<countOptions>
let parseUrlOptions: {..} => option<urlOptions>
let parseJsonOptions: {..} => option<jsonOptions>
let parseDateOptions: {..} => option<dateOptions>
let parseListOptions: {..} => listOptions
let parseTableOptions: {..} => result<tableOptions, string>
