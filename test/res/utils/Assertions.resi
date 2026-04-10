/**
 * Asserts that a text value matches an expected string.
 * @param {string} expected - The expected string value
 * @param {string} actual - The actual string value to test
 * @param {string=} message - Optional custom message to display on assertion failure
 * @returns {unit}
 */
let isTextEqualTo: (string, string, ~message: string=?) => unit

/**
 * Asserts that a boolean value is true.
 * @param {bool} a - The boolean value to test
 * @param {string=} message - Optional custom message to display on assertion failure
 * @returns {unit}
 */
let isTruthy: (bool, ~message: string=?) => unit

/**
 * Asserts that an integer value matches an expected integer.
 * @param {int} expected - The expected integer value
 * @param {int} actual - The actual integer value to test
 * @param {string=} message - Optional custom message to display on assertion failure
 * @returns {unit}
 */
let isIntEqualTo: (int, int, ~message: string=?) => unit

/**
 * Asserts that a float value matches an expected float value within epsilon.
 * @param {float} expected - The expected float value
 * @param {float} actual - The actual float value to test
 * @param {float=} epsilon - Allowed absolute difference
 * @param {string=} message - Optional custom message to display on assertion failure
 * @returns {unit}
 */
let isFloatEqualTo: (float, float, ~epsilon: float=?, ~message: string=?) => unit

/**
 * Asserts that two option values are equal using a caller-provided comparator.
 * @param {option<'a>} expected - The expected option value
 * @param {option<'a>} actual - The actual option value
 * @param {('a, 'a) => bool} eq - Comparator for inner values
 * @param {string=} message - Optional custom message to display on assertion failure
 * @returns {unit}
 */
let isOptionEqualTo: (option<'a>, option<'a>, ~eq: ('a, 'a) => bool, ~message: string=?) => unit

/**
 * Asserts that a result is Ok(_).
 * @param {result<'a, 'b>} value - Result value to test
 * @param {string=} message - Optional custom message to display on assertion failure
 * @returns {unit}
 */
let isResultOk: (result<'a, 'b>, ~message: string=?) => unit

/**
 * Asserts that a result is Error(_).
 * @param {result<'a, 'b>} value - Result value to test
 * @param {string=} message - Optional custom message to display on assertion failure
 * @returns {unit}
 */
let isResultError: (result<'a, 'b>, ~message: string=?) => unit

/**
 * Asserts that a JSON value is null.
 * @param {JSON.t} value - JSON value to test
 * @param {string=} message - Optional custom message to display on assertion failure
 * @returns {unit}
 */
let isNull: (JSON.t, ~message: string=?) => unit

/**
 * Asserts JSON structural equality via JSON.stringify.
 * @param {JSON.t} expected - Expected JSON value
 * @param {JSON.t} actual - Actual JSON value
 * @param {string=} message - Optional custom message to display on assertion failure
 * @returns {unit}
 */
let isJsonEqualTo: (JSON.t, JSON.t, ~message: string=?) => unit

/**
 * Explicitly marks a test as passed with a custom message.
 * @param {string} message - Success message to display
 * @returns {unit}
 */
let passWith: string => unit

/**
 * Explicitly fails a test with a custom message.
 * @param {string} message - Failure message to display
 * @returns {unit}
 * @throws Will throw an exception to fail the current test
 */
let failWith: string => unit
