/** Merges per-field options with schema-level defaults.
  * Field options take precedence over defaults; unset fields fall back to defaults.
  */
open FieldTypes

/** Picks the field value when set; falls back to the default otherwise. */
let pickOption = (current, fallback) =>
  switch current {
  | Some(value) => Some(value)
  | None => fallback
  }

/** Shared nested-switch pattern for the 7 per-record merge*Options helpers.
  * Per-record merging logic is supplied as `mergeFn(field, default)`.
  * `mergeCountOptions` keeps its own pass-through shape and does not use this.
  */
let applyDefaults = (
  fieldOpts: option<'a>,
  defaultOpts: option<'a>,
  mergeFn: ('a, 'a) => 'a,
): option<'a> =>
  switch defaultOpts {
  | None => fieldOpts
  | Some(def) =>
    switch fieldOpts {
    | None => Some(def)
    | Some(opts) => Some(mergeFn(opts, def))
    }
  }

let mergeTextOptions = (fieldOpts: option<textOptions>, defaultOpts: option<textOptions>) =>
  applyDefaults(fieldOpts, defaultOpts, (opts, def) => {
    trim: ?pickOption(opts.trim, def.trim),
    normalizeWhitespace: ?pickOption(opts.normalizeWhitespace, def.normalizeWhitespace),
    lowercase: ?pickOption(opts.lowercase, def.lowercase),
    uppercase: ?pickOption(opts.uppercase, def.uppercase),
    pattern: ?pickOption(opts.pattern, def.pattern),
    join: ?pickOption(opts.join, def.join),
  })

let mergeHtmlOptions = (fieldOpts: option<htmlOptions>, defaultOpts: option<htmlOptions>) =>
  applyDefaults(fieldOpts, defaultOpts, (opts, def) => {
    mode: ?pickOption(opts.mode, def.mode),
    stripScripts: ?pickOption(opts.stripScripts, def.stripScripts),
    stripStyles: ?pickOption(opts.stripStyles, def.stripStyles),
  })

let mergeNumberOptions = (fieldOpts: option<numberOptions>, defaultOpts: option<numberOptions>) =>
  applyDefaults(fieldOpts, defaultOpts, (opts, def) => {
    stripNonNumeric: ?pickOption(opts.stripNonNumeric, def.stripNonNumeric),
    pattern: ?pickOption(opts.pattern, def.pattern),
    thousandsSeparator: ?pickOption(opts.thousandsSeparator, def.thousandsSeparator),
    decimalSeparator: ?pickOption(opts.decimalSeparator, def.decimalSeparator),
    precision: ?pickOption(opts.precision, def.precision),
    allowNegative: ?pickOption(opts.allowNegative, def.allowNegative),
    onError: ?pickOption(opts.onError, def.onError),
  })

let mergeBooleanOptions = (
  fieldOpts: option<booleanOptions>,
  defaultOpts: option<booleanOptions>,
) =>
  applyDefaults(fieldOpts, defaultOpts, (opts, def) => {
    mode: ?pickOption(opts.mode, def.mode),
    trueValues: ?pickOption(opts.trueValues, def.trueValues),
    falseValues: ?pickOption(opts.falseValues, def.falseValues),
    attribute: ?pickOption(opts.attribute, def.attribute),
    onUnknown: ?pickOption(opts.onUnknown, def.onUnknown),
  })

/** Pass-through (no per-field merge needed for the empty countOptions record). */
let mergeCountOptions = (fieldOpts: option<countOptions>, defaultOpts: option<countOptions>) =>
  switch fieldOpts {
  | Some(_) => fieldOpts
  | None => defaultOpts
  }

let mergeDateOptions = (fieldOpts: option<dateOptions>, defaultOpts: option<dateOptions>) =>
  applyDefaults(fieldOpts, defaultOpts, (opts, def) => {
    formats: ?pickOption(opts.formats, def.formats),
    timezone: ?pickOption(opts.timezone, def.timezone),
    output: ?pickOption(opts.output, def.output),
    strict: ?pickOption(opts.strict, def.strict),
    source: ?pickOption(opts.source, def.source),
    attribute: ?pickOption(opts.attribute, def.attribute),
  })

let mergeUrlOptions = (fieldOpts: option<urlOptions>, defaultOpts: option<urlOptions>) =>
  applyDefaults(fieldOpts, defaultOpts, (opts, def) => {
    base: ?pickOption(opts.base, def.base),
    resolve: ?pickOption(opts.resolve, def.resolve),
    validate: ?pickOption(opts.validate, def.validate),
    protocol: ?pickOption(opts.protocol, def.protocol),
    stripQuery: ?pickOption(opts.stripQuery, def.stripQuery),
    stripHash: ?pickOption(opts.stripHash, def.stripHash),
    attribute: ?pickOption(opts.attribute, def.attribute),
  })

let mergeJsonOptions = (fieldOpts: option<jsonOptions>, defaultOpts: option<jsonOptions>) =>
  applyDefaults(fieldOpts, defaultOpts, (opts, def) => {
    source: ?pickOption(opts.source, def.source),
    attribute: ?pickOption(opts.attribute, def.attribute),
    path: ?pickOption(opts.path, def.path),
    onError: ?pickOption(opts.onError, def.onError),
  })

let resolveDefaults = (defaults: option<schemaDefaults>, fieldType: fieldType): fieldType => {
  // Replaces the repeated `switch defaults { Some(d) => d.X | None => None }`
  // pattern that appeared once per visitor callback. `extract` is the per-field
  // accessor (e.g. `d => d.text`); the closure handles the outer Some/None.
  let lookup = extract =>
    switch defaults {
    | Some(d) => extract(d)
    | None => None
    }
  let visitor: FieldTypeVisitor.fieldTypeVisitor<fieldType> = {
    text: opts => Text(mergeTextOptions(opts, lookup(d => d.text))),
    attribute: cfg => Attribute(cfg),
    html: opts => Html(mergeHtmlOptions(opts, lookup(d => d.html))),
    number: opts => Number(mergeNumberOptions(opts, lookup(d => d.number))),
    boolean: opts => Boolean(mergeBooleanOptions(opts, lookup(d => d.boolean))),
    count: opts => Count(mergeCountOptions(opts, lookup(d => d.count))),
    url: opts => Url(mergeUrlOptions(opts, lookup(d => d.url))),
    json: opts => Json(mergeJsonOptions(opts, lookup(d => d.json))),
    datetime: opts => DateTime(mergeDateOptions(opts, lookup(d => d.datetime))),
    list: opts => List(opts),
    table: opts => Table(opts),
  }
  FieldTypeVisitor.visitFieldType(visitor, fieldType)
}
