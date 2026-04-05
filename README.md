# res-scrapy

Command-line HTML scraper written in ReScript. Reads HTML from stdin and
outputs JSON to stdout. Designed to be simple, scriptable and useful for
small scraping tasks and structured extraction via JSON schemas.

- **Version:** 0.1.0
- **Author:** José Martínez Santana
- **Repository:** https://github.com/MetalbolicX/res-scrapy

## Features

- Read HTML from `stdin` and extract content using CSS selectors.
- Extract `outerHtml`, `innerHtml`, `text`, or an element attribute (`attr:name`).
- Support for single or multiple results (`--mode` / `-m`).
- Schema-driven structured extraction via `--schema` (inline JSON) or
  `--schemaPath` (path to a `.json` schema file).
- Outputs JSON to `stdout`, prints errors to `stderr` and exits non-zero on failure.

## Requirements

- Node.js >= 22.0.0
- A JavaScript package manager (pnpm is used in this repo)

## Install & Build

Install dependencies and build the distributable in `dist/`:

```bash
pnpm install
pnpm run build
```

During development you can watch ReScript sources:

```bash
pnpm run res:dev
```

The package exposes a `bin` entry (`res-scrapy`) and the built CLI is
`dist/main.js`.

## Usage

The CLI reads HTML from `stdin` and writes a JSON array (or object) to
`stdout`.

Basic help (built-in):

```bash
node dist/main.js --help
```

Example flags (shorthand shown in parentheses):

- `-h, --help` : Display this help message
- `-s, --selector` : CSS selector to extract (required unless using `--schema`)
- `-m, --mode` : Extract multiple results (boolean flag; default is single)
- `-e, --extract` : What to extract: `outerHtml` (default), `innerHtml`, `text`, or `attr:<name>`
- `-c, --schema` : Inline JSON schema (string)
- `-p, --schemaPath` : Path to a JSON schema file

Examples:

```bash
# Extract the text of the first matching element
cat examples/sample.html | node dist/main.js -s '.product-title' -e text

# Extract all links (attribute) from a document
curl -s 'https://example.com' | node dist/main.js -s 'a.article-link' -m -e 'attr:href'

# Use a schema file to produce structured JSON rows
cat examples/sample.html | node dist/main.js -p examples/schema-product.json
```

Notes:

- When running via `pnpm start` pass CLI flags after `--`, e.g.
  `cat file.html | pnpm start -- --selector '.foo' -m`.
- The CLI validates arguments and will exit with code `1` and print an
  error message on failure.

## Schema-driven extraction

When `--schema` (inline JSON) or `--schemaPath` (file) is provided, the
tool attempts structured extraction according to the schema. See
`examples/schema-product.json` for an example schema format.

## Examples and testing

See the included `examples/` folder for `sample.html` and
`schema-product.json` to try the scraper locally.

## License

This project is released under the MIT License.
