# Getting Started

**res-scrapy** can work in any JavaScript environment, including Node.js, Deno, Bun and browsers. To get started, you need to install the CLI tool.

## For Node.js

To work with Node.js, you must have **version 22.0.0** or higher installed.

Check your Node.js version with the following command:

```sh
node -v
```

If you do not have Node.js installed in your current environment, or the installed version is too low, you can use [nvm](https://github.com/nvm-sh/nvm) to install the latest version of Node.js.

### Install the CLI

To use the command-line tool, install the published package and then run the `res-scrapy` command.

Recommended (global install):

```sh
npm install -g res-scrapy
res-scrapy -v
res-scrapy -h
```

One-off (no global install):

<!-- tabs:start -->

#### **npm**

```sh
npx res-scrapy -h
```

#### **pnpm**

```sh
pnpm dlx res-scrapy -h
```

#### **yarn**

```sh
yarn dlx res-scrapy -h
```

#### **bun**

```sh
bunx res-scrapy -h
```

<!-- tabs:end -->

Local development (from repo root):

```sh
npm link
res-scrapy -h
```

Install from a packed tarball:

```sh
npm pack
npm install -g ./res-scrapy-<version>.tgz
res-scrapy -h
```

> [!Note] If global installs require elevated permissions, use a node version manager (nvm, fnm, asdf) or prefer the `npx`/`dlx` one-off commands.
