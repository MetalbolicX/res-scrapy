open FieldTypes

let mergeTextOptions: (option<textOptions>, option<textOptions>) => option<textOptions>
let mergeHtmlOptions: (option<htmlOptions>, option<htmlOptions>) => option<htmlOptions>
let mergeNumberOptions: (option<numberOptions>, option<numberOptions>) => option<numberOptions>
let mergeBooleanOptions: (option<booleanOptions>, option<booleanOptions>) => option<booleanOptions>
let mergeCountOptions: (option<countOptions>, option<countOptions>) => option<countOptions>
let mergeDateOptions: (option<dateOptions>, option<dateOptions>) => option<dateOptions>
let mergeUrlOptions: (option<urlOptions>, option<urlOptions>) => option<urlOptions>
let mergeJsonOptions: (option<jsonOptions>, option<jsonOptions>) => option<jsonOptions>
let resolveDefaults: (option<schemaDefaults>, fieldType) => fieldType
