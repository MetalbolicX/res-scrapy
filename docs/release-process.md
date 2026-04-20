# Release Process

This project follows Semantic Versioning (`MAJOR.MINOR.PATCH`).

## Versioning Rules

- `PATCH`: bug fixes, docs corrections, and internal refactors with no breaking behavior.
- `MINOR`: backward-compatible features and CLI/schema option additions.
- `MAJOR`: breaking changes to CLI flags, schema behavior, output format, or Node runtime requirements.

## Pre-release Checklist

Run these commands from the repository root:

```sh
pnpm install --frozen-lockfile
pnpm run res:build
pnpm run res:test
pnpm run bundle
pnpm run date:check
```

## Publish Steps

1. Update `CHANGELOG.md`:
   - Move relevant entries from `[Unreleased]` into a new version section.
   - Keep entries grouped under Added/Changed/Fixed/Security.
2. Bump package version:

   ```sh
   npm version patch   # or minor / major
   ```

3. Verify packed contents before publishing:

   ```sh
   npm pack --dry-run
   ```

4. Publish:

   ```sh
   npm publish
   ```

5. Create a GitHub release from the version tag and include changelog notes.

## Post-release Checks

- Install from registry and validate CLI:

  ```sh
  npx res-scrapy --version
  npx res-scrapy --help
  ```

- Run a smoke extraction against a known fixture.
