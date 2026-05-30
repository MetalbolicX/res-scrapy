# Skill Registry

## Project Context
- Project: res-scrapy
- Stack: ReScript CLI compiled to Node.js 22+
- Test runner: `pnpm run res:test` (`rescript-test` via `retest`)
- Coverage: `pnpm run res:coverage` (`c8`)

## Project Conventions
- Keep changes small and test-backed.
- Prefer ReScript-native code; isolate raw JS/FFI usage.
- Treat schema input as untrusted; validate before execution.
- Use strict TDD for behavior changes because a test runner is available.

## Relevant Skills

### diagnose
Trigger: bugs, failures, regressions, or security issues.
Compact rules:
- Reproduce first, then minimise.
- Form 3-5 falsifiable hypotheses before testing fixes.
- Instrument one variable at a time.
- Add regression tests before the fix when a proper seam exists.
- Remove all debug instrumentation before finishing.

### test-driven-development
Trigger: feature or bugfix implementation.
Compact rules:
- Write the failing test first.
- Make the smallest change to pass.
- Keep tests close to the affected behavior.
- Prefer regression tests that exercise the real call site.

### verification-before-completion
Trigger: about to claim done, fixed, or passing.
Compact rules:
- Run the relevant tests before saying the work is complete.
- Confirm the output, don’t infer success.
- If verification fails, fix the issue before concluding.

### web-coder
Trigger: HTML, HTTP, security, web APIs, or browser-adjacent behavior.
Compact rules:
- Treat user-supplied HTML and URLs as untrusted.
- Be explicit about XSS/SSRF and URL handling risks.
- Prefer standards-compliant URL and HTTP behavior.

### ast-grep
Trigger: structural code search or refactors.
Compact rules:
- Use AST-aware search for code patterns, not plain text heuristics.
- Match complete nodes and preserve syntax when rewriting.
- Prefer structural refactors for repeated code paths.

### code-review
Trigger: security review or change review.
Compact rules:
- Separate blocking issues from suggestions.
- Cite exact file/line evidence.
- Explain why the issue matters and how to fix it.
