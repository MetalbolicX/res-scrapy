/** Merges per-field options with schema-level defaults.
  * Field options take precedence over defaults; unset fields fall back to defaults.
  */
open FieldTypes

let pickOption = (current, fallback) =>
  switch current {
  | Some(value) => Some(value)
  | None => fallback
  }

let mergeTextOptions = (fieldOpts: option<textOptions>, defaultOpts: option<textOptions>) =>
  switch defaultOpts {
  | None => fieldOpts
  | Some(def) =>
    switch fieldOpts {
    | None => Some(def)
    | Some(opts) =>
      Some({
        trim: ?pickOption(opts.trim, def.trim),
        normalizeWhitespace: ?pickOption(opts.normalizeWhitespace, def.normalizeWhitespace),
        lowercase: ?pickOption(opts.lowercase, def.lowercase),
        uppercase: ?pickOption(opts.uppercase, def.uppercase),
        pattern: ?pickOption(opts.pattern, def.pattern),
        join: ?pickOption(opts.join, def.join),
      })
    }
  }

let mergeHtmlOptions = (fieldOpts: option<htmlOptions>, defaultOpts: option<htmlOptions>) =>
  switch defaultOpts {
  | None => fieldOpts
  | Some(def) =>
    switch fieldOpts {
    | None => Some(def)
    | Some(opts) =>
      Some({
        mode: ?pickOption(opts.mode, def.mode),
        stripScripts: ?pickOption(opts.stripScripts, def.stripScripts),
        stripStyles: ?pickOption(opts.stripStyles, def.stripStyles),
      })
    }
  }

let mergeNumberOptions = (fieldOpts: option<numberOptions>, defaultOpts: option<numberOptions>) =>
  switch defaultOpts {
  | None => fieldOpts
  | Some(def) =>
    switch fieldOpts {
    | None => Some(def)
    | Some(opts) =>
      Some({
        stripNonNumeric: ?pickOption(opts.stripNonNumeric, def.stripNonNumeric),
        pattern: ?pickOption(opts.pattern, def.pattern),
        thousandsSeparator: ?pickOption(opts.thousandsSeparator, def.thousandsSeparator),
        decimalSeparator: ?pickOption(opts.decimalSeparator, def.decimalSeparator),
        precision: ?pickOption(opts.precision, def.precision),
        allowNegative: ?pickOption(opts.allowNegative, def.allowNegative),
        onError: ?pickOption(opts.onError, def.onError),
      })
    }
  }

let mergeBooleanOptions = (
  fieldOpts: option<booleanOptions>,
  defaultOpts: option<booleanOptions>,
) =>
  switch defaultOpts {
  | None => fieldOpts
  | Some(def) =>
    switch fieldOpts {
    | None => Some(def)
    | Some(opts) =>
      Some({
        mode: ?pickOption(opts.mode, def.mode),
        trueValues: ?pickOption(opts.trueValues, def.trueValues),
        falseValues: ?pickOption(opts.falseValues, def.falseValues),
        attribute: ?pickOption(opts.attribute, def.attribute),
        onUnknown: ?pickOption(opts.onUnknown, def.onUnknown),
      })
    }
  }

let mergeCountOptions = (fieldOpts: option<countOptions>, defaultOpts: option<countOptions>) =>
  switch fieldOpts {
  | Some(_) => fieldOpts
  | None => defaultOpts
  }

let mergeDateOptions = (fieldOpts: option<dateOptions>, defaultOpts: option<dateOptions>) =>
  switch defaultOpts {
  | None => fieldOpts
  | Some(def) =>
    switch fieldOpts {
    | None => Some(def)
    | Some(opts) =>
      Some({
        formats: ?pickOption(opts.formats, def.formats),
        timezone: ?pickOption(opts.timezone, def.timezone),
        output: ?pickOption(opts.output, def.output),
        strict: ?pickOption(opts.strict, def.strict),
        source: ?pickOption(opts.source, def.source),
        attribute: ?pickOption(opts.attribute, def.attribute),
      })
    }
  }

let mergeUrlOptions = (fieldOpts: option<urlOptions>, defaultOpts: option<urlOptions>) =>
  switch defaultOpts {
  | None => fieldOpts
  | Some(def) =>
    switch fieldOpts {
    | None => Some(def)
    | Some(opts) =>
      Some({
        base: ?pickOption(opts.base, def.base),
        resolve: ?pickOption(opts.resolve, def.resolve),
        validate: ?pickOption(opts.validate, def.validate),
        protocol: ?pickOption(opts.protocol, def.protocol),
        stripQuery: ?pickOption(opts.stripQuery, def.stripQuery),
        stripHash: ?pickOption(opts.stripHash, def.stripHash),
        attribute: ?pickOption(opts.attribute, def.attribute),
      })
    }
  }

let mergeJsonOptions = (fieldOpts: option<jsonOptions>, defaultOpts: option<jsonOptions>) =>
  switch defaultOpts {
  | None => fieldOpts
  | Some(def) =>
    switch fieldOpts {
    | None => Some(def)
    | Some(opts) =>
      Some({
        source: ?pickOption(opts.source, def.source),
        attribute: ?pickOption(opts.attribute, def.attribute),
        path: ?pickOption(opts.path, def.path),
        onError: ?pickOption(opts.onError, def.onError),
      })
    }
  }

let resolveDefaults = (defaults: option<schemaDefaults>, fieldType: fieldType): fieldType => {
  let visitor: FieldTypeVisitor.fieldTypeVisitor<fieldType> = {
    text: opts => Text(
      mergeTextOptions(
        opts,
        switch defaults {
        | Some(d) => d.text
        | None => None
        },
      ),
    ),
    attribute: cfg => Attribute(cfg),
    html: opts => Html(
      mergeHtmlOptions(
        opts,
        switch defaults {
        | Some(d) => d.html
        | None => None
        },
      ),
    ),
    number: opts => Number(
      mergeNumberOptions(
        opts,
        switch defaults {
        | Some(d) => d.number
        | None => None
        },
      ),
    ),
    boolean: opts => Boolean(
      mergeBooleanOptions(
        opts,
        switch defaults {
        | Some(d) => d.boolean
        | None => None
        },
      ),
    ),
    count: opts => Count(
      mergeCountOptions(
        opts,
        switch defaults {
        | Some(d) => d.count
        | None => None
        },
      ),
    ),
    url: opts => Url(
      mergeUrlOptions(
        opts,
        switch defaults {
        | Some(d) => d.url
        | None => None
        },
      ),
    ),
    json: opts => Json(
      mergeJsonOptions(
        opts,
        switch defaults {
        | Some(d) => d.json
        | None => None
        },
      ),
    ),
    datetime: opts => DateTime(
      mergeDateOptions(
        opts,
        switch defaults {
        | Some(d) => d.datetime
        | None => None
        },
      ),
    ),
    list: opts => List(opts),
    table: opts => Table(opts),
  }
  FieldTypeVisitor.visitFieldType(visitor, fieldType)
}
