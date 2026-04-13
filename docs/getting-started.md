# Getting Started

**res-scrapy** can work in any JavaScript environment, including Node.js, Deno, Bun and browsers. To get started, you need to install the library and import it into your project.

## For Node.js

To work with Node.js, you must have version 22.0.0 or higher installed.

Check your Node.js version with the following command:

```sh
node -v
```

If you do not have Node.js installed in your current environment, or the installed version is too low, you can use [nvm](https://github.com/nvm-sh/nvm) to install the latest version of Node.js.

## Create a new project

Navigate to the folder where your project will be created and run the following command to create a new directory:

```sh
mkdir app && cd app
```

Initialize a `package.json` file using one of the following commands:

<!-- tabs:start -->

#### **npm**

```sh
npm init
```

#### **pnpm**

```sh
pnpm init
```

#### **yarn**

```sh
yarn init
```

#### **bun**

```sh
bun init
```

#### **deno**

```sh
deno init
```

<!-- tabs:end -->

### Install the CLI

To use the command-line tool, install the published package and then run the `res-scrapy` command.

Recommended (global install):

```sh
npm install -g res-scrapy
res-scrapy -h
```

One-off (no global install):

```sh
npx res-scrapy -h          # npm
pnpm dlx res-scrapy -h     # pnpm
yarn dlx res-scrapy -h     # yarn
bunx res-scrapy -h         # bun
```

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

Notes:

- Ensure you have Node.js v22.0.0 or later (`node -v`).
- If global installs require elevated permissions, use a node version manager (nvm, fnm, asdf) or prefer the `npx`/`dlx` one-off commands.
