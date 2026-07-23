# Delta for output-error-contract

> No main spec exists for this domain yet. This delta establishes the
> post-change behaviour for the URL-output error contract. The
> archive step will promote this to
> `openspec/specs/output-error-contract/spec.md`.

## ADDED Requirements

### Requirement: UrlOutputWriter Returns Typed Errors

Every public function in `UrlOutputWriter` that previously returned
`result<_, string>` MUST return `result<_, AppError.appError>`. The
error MUST be `AppError.WriteError(msg)` where `msg` includes the
operation description, the path, and the underlying exception message.

#### Scenario: appendNdjsonToFile returns AppError.WriteError on failure

- GIVEN `appendFile` throws an exception
- WHEN `appendNdjsonToFile` is called
- THEN it returns `Error(AppError.WriteError("Failed to append to output file \"<path>\": <exn.message>"))`
- AND the warning `"Warning: Failed to append to output file \"<path>\": <exn.message>"` is emitted on `err`

#### Scenario: beginJsonArraySync returns AppError.WriteError on failure

- GIVEN `writeFileSync` throws an exception
- WHEN `beginJsonArraySync` is called
- THEN it returns `Error(AppError.WriteError("Failed to open JSON output file \"<path>\": <exn.message>"))`

#### Scenario: appendJsonRowAsync returns AppError.WriteError on failure

- GIVEN `appendFile` throws an exception
- WHEN `appendJsonRowAsync` is called
- THEN it returns `Error(AppError.WriteError("Failed to append to JSON output file \"<path>\": <exn.message>"))`

#### Scenario: endJsonArraySync returns AppError.WriteError on failure

- GIVEN `appendFileSync` throws an exception
- WHEN `endJsonArraySync` is called
- THEN it returns `Error(AppError.WriteError("Failed to close JSON output file \"<path>\": <exn.message>"))`

### Requirement: Warnings Emit Human-Readable Strings

The `emitWriteError` helper MUST call `err` with a string that begins
with `"Warning: "` and contains the operation description, path, and
exception message. The string is derived via `AppError.toMessage` from
the typed error.

#### Scenario: Warning string format

- GIVEN an exception with message `"EACCES"`
- WHEN `emitWriteError` is called with `~operation="Failed to append to output file"`, `~path="/tmp/out.json"`
- THEN `err` receives `"Warning: Failed to append to output file \"/tmp/out.json\": EACCES"`

### Requirement: UrlRunner Aggregates Typed Errors

The `UrlRunner.runUrlMode` function MUST treat any returned
`AppError.appError` from `UrlOutputWriter` as a write failure and
increment the `writeFailures` counter. The final exit-time warning MUST
use `AppError.toMessage` to produce the human-readable string.

#### Scenario: writeFailures counter increments on AppError

- GIVEN `routeOutput` returns `Error(appErr)` from `appendNdjsonToFile`
- WHEN `UrlRunner` processes the failure
- THEN `state.writeFailures` increases by `1`

#### Scenario: Final warning uses toMessage

- GIVEN `state.writeFailures == 3` after the run
- WHEN the exit-time warning is emitted
- THEN the message is `"Warning: 3 output write(s) failed"`
- AND any individual error surfaces through `AppError.toMessage` when relevant
