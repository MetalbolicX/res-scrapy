# Plan 001: Fix DX, CI, and doc inaccuracies

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `8e085f5`, 2026-06-30

## Why this matters

Four small but high-ROI issues undermine developer trust and CI reliability:
a broken security audit script, no formatting check in CI, a `coverage/`
directory that can leak into git, and a `copilot-instructions.md` that
falsely claims there are no automated tests. Each is a 1–5 line change.

## Current state

**1. Broken security audit script** — `package.json:24`:
```json
"security:audit": "npm audit --audit-level=high"
```
The project uses `pnpm-lock.yaml` (not `package-lock.json`), so `npm audit`
exits with `ENOLOCK`. The script has never worked.

**2. No formatting lint step** — `.github/workflows/ci.yml` runs only:
```
pnpm run res:build → pnpm run res:test → pnpm run bundle
```
No `rescript format --check` step. `package.json` has no lint script.
ReScript ships a built-in formatter (`rescript format`).

**3. `coverage/` not in `.gitignore`** — `.gitignore` (lines 27, 96) has
`coverage` and `dist` for other tools, but no `/coverage/` entry. The `c8`
coverage tool writes to `coverage/` (used by `pnpm run res:coverage`).
This directory exists on disk already.

**4. `copilot-instructions.md` claims no tests** — `.github/copilot-instructions.md:15`:
```
There are no automated test or lint scripts in package.json.
```
But `package.json:15` defines `"res:test": "retest ./test/res/*.res.mjs"`,
which runs 432 tests / 855 assertions. The instruction is actively wrong.

## Commands you will need

| Purpose   | Command                          | Expected on success |
|-----------|----------------------------------|---------------------|
| Build     | `pnpm run res:build`             | exit 0              |
| Tests     | `pnpm run res:test`              | all pass            |
| Audit     | `pnpm run security:audit`        | exit 0 (or advisory output) |
| Format    | `npx rescript format --check src/ test/` | exit 0 (no diffs reported) |

## Scope

**In scope**:
- `package.json` — fix `security:audit` script, optionally add `res:lint`
- `.github/workflows/ci.yml` — add format-check step
- `.gitignore` — add `/coverage/` entry
- `.github/copilot-instructions.md` — fix the "no tests" claim

**Out of scope**:
- Any `.res` source file changes
- Any changes to `rolldown.config.mjs`, `tsconfig.date.json`
- Pre-commit hooks (separate concern)

## Steps

### Step 1: Fix the security audit script

In `package.json`, change line 24 from:
```json
"security:audit": "npm audit --audit-level=high",
```
to:
```json
"security:audit": "pnpm audit --audit-level=high",
```

**Verify**: `pnpm run security:audit` → exits 0 or prints advisory output
(no ENOLOCK error).

### Step 2: Add format-check script to package.json

In `package.json`, add a new script entry after `security:audit`:
```json
"res:lint": "rescript format --check src/ test/",
```

**Verify**: `pnpm run res:lint` → exits 0 if formatting is clean. If it
reports diffs, run `npx rescript format src/ test/` to normalize first, then
re-check.

### Step 3: Add format-check step to CI

In `.github/workflows/ci.yml`, after the "Build ReScript" step and before
"Run tests", add:
```yaml
      - name: Check formatting
        run: pnpm run res:lint
```

**Verify**: Read the file back and confirm the step exists between build and test.

### Step 4: Add coverage/ to .gitignore

In `.gitignore`, after the `dist` entry (line 96), add:
```
# Coverage reports
/coverage/
```

**Verify**: `git status coverage/` should show it as ignored (or not
tracked). Run `git check-ignore coverage/` → prints `coverage/`.

### Step 5: Fix copilot-instructions.md

In `.github/copilot-instructions.md`, replace line 15:
```
- There are no automated test or lint scripts in package.json. Use the examples in `examples/` for manual verification.
```
with:
```
- Run tests: `pnpm run res:test` (432 tests via rescript-test).
- Run coverage: `pnpm run res:coverage` (uses c8).
- Check formatting: `pnpm run res:lint` (runs `rescript format --check`).
```

Also fix line 37: it says `dist/main.js` but the actual bundle output is
`dist/main.mjs` (see `rolldown.config.mjs:11`).

**Verify**: Read the file back. Confirm the test commands match `package.json`.

## Done criteria

- [ ] `pnpm run security:audit` does not error with ENOLOCK
- [ ] `pnpm run res:lint` script exists in `package.json`
- [ ] `.github/workflows/ci.yml` has a format-check step
- [ ] `git check-ignore coverage/` prints `coverage/`
- [ ] `.github/copilot-instructions.md` no longer claims "no automated test"
- [ ] No `.res` source files are modified

## STOP conditions

- `rescript format --check` reports diffs that cannot be auto-fixed
  (run `rescript format` to fix, then re-check).
- The CI YAML has a different structure than the excerpt above.
