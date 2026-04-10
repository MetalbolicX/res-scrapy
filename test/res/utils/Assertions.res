open Test

let absFloat = n => n < 0.0 ? -.n : n

/**
 * Asserts that a text value matches an expected string.
 * @param {string} originalText - The expected string value
 * @param {string} textToCompare - The actual string value to test
 * @param {string=} message - Optional custom message to display on assertion failure
 * @returns {unit}
 */
let isTextEqualTo: (string, string, ~message: string=?) => unit = (
  originalText,
  textToCompare,
  ~message as msg="",
) =>
  assertion(
    (originalText, textToCompare) => originalText->String.equal(textToCompare),
    originalText,
    textToCompare,
    ~operator="String equals to",
    ~message=msg,
  )

/**
 * Asserts that a boolean value is true.
 * @param {bool} a - The boolean value to test
 * @param {string=} message - Optional custom message to display on assertion failure
 * @returns {unit}
 */
let isTruthy: (bool, ~message: string=?) => unit = (a, ~message as msg="") =>
  assertion((a, b) => a == b, a, true, ~operator="Equals to true", ~message=msg)

/**
 * Asserts that an integer value matches an expected integer.
 * @param {int} a - The expected integer value
 * @param {int} b - The actual integer value to test
 * @param {string=} message - Optional custom message to display on assertion failure
 * @returns {unit}
 */
let isIntEqualTo: (int, int, ~message: string=?) => unit = (a, b, ~message as msg="") =>
  assertion((a, b) => a == b, a, b, ~operator="Integer equals to", ~message=msg)

/**
 * Asserts that a float value matches an expected float value within epsilon.
 * @param {float} expected - The expected float value
 * @param {float} actual - The actual float value to test
 * @param {float=} epsilon - Allowed absolute difference (default: 0.000001)
 * @param {string=} message - Optional custom message to display on assertion failure
 * @returns {unit}
 */
let isFloatEqualTo: (float, float, ~epsilon: float=?, ~message: string=?) => unit = (
  expected,
  actual,
  ~epsilon=?,
  ~message as msg="",
) => {
  let tolerance = Option.getOr(epsilon, 0.000001)
  assertion(
    (a, b) => absFloat(a -. b) <= tolerance,
    expected,
    actual,
    ~operator="Float equals to",
    ~message=msg,
  )
}

/**
 * Asserts that two option values are equal using a caller-provided comparator.
 * @param {option<'a>} expected - The expected option value
 * @param {option<'a>} actual - The actual option value
 * @param {('a, 'a) => bool} eq - Comparator for inner values
 * @param {string=} message - Optional custom message to display on assertion failure
 * @returns {unit}
 */
let isOptionEqualTo: (
  option<'a>,
  option<'a>,
  ~eq: ('a, 'a) => bool,
  ~message: string=?,
) => unit = (expected, actual, ~eq, ~message as msg="") => {
  let isEqual = switch (expected, actual) {
  | (None, None) => true
  | (Some(a), Some(b)) => eq(a, b)
  | _ => false
  }
  assertion((a, b) => a == b, isEqual, true, ~operator="Option equals to", ~message=msg)
}

/**
 * Asserts that a result is Ok(_).
 * @param {result<'a, 'b>} value - Result value to test
 * @param {string=} message - Optional custom message to display on assertion failure
 * @returns {unit}
 */
let isResultOk: (result<'a, 'b>, ~message: string=?) => unit = (value, ~message as msg="") => {
  let ok = switch value {
  | Ok(_) => true
  | Error(_) => false
  }
  assertion((a, b) => a == b, ok, true, ~operator="Result is Ok", ~message=msg)
}

/**
 * Asserts that a result is Error(_).
 * @param {result<'a, 'b>} value - Result value to test
 * @param {string=} message - Optional custom message to display on assertion failure
 * @returns {unit}
 */
let isResultError: (result<'a, 'b>, ~message: string=?) => unit = (
  value,
  ~message as msg="",
) => {
  let hasError = switch value {
  | Ok(_) => false
  | Error(_) => true
  }
  assertion((a, b) => a == b, hasError, true, ~operator="Result is Error", ~message=msg)
}

/**
 * Asserts that a JSON value is null.
 * @param {JSON.t} value - JSON value to test
 * @param {string=} message - Optional custom message to display on assertion failure
 * @returns {unit}
 */
let isNull: (JSON.t, ~message: string=?) => unit = (value, ~message as msg="") =>
  assertion(
    (a, b) => a == b,
    NodeJsBinding.jsonStringify(value),
    "null",
    ~operator="JSON is null",
    ~message=msg,
  )

/**
 * Asserts JSON structural equality via JSON.stringify.
 * @param {JSON.t} expected - Expected JSON value
 * @param {JSON.t} actual - Actual JSON value
 * @param {string=} message - Optional custom message to display on assertion failure
 * @returns {unit}
 */
let isJsonEqualTo: (JSON.t, JSON.t, ~message: string=?) => unit = (expected, actual, ~message as msg="") =>
  assertion(
    (a, b) => a == b,
    NodeJsBinding.jsonStringify(expected),
    NodeJsBinding.jsonStringify(actual),
    ~operator="JSON equals to",
    ~message=msg,
  )

/**
 * Explicitly marks a test as passed with a custom message.
 * @param {string} message - Success message to display
 * @returns {unit}
 */
let passWith: string => unit = message => isTruthy(true, ~message)

/**
 * Explicitly fails a test with a custom message.
 * @param {string} message - Failure message to display
 * @returns {unit}
 * @throws Will throw an exception to fail the current test
 */
let failWith: string => unit = message => isTruthy(false, ~message)
