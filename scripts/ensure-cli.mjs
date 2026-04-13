// scripts/ensure-cli.mjs
import fs from 'fs/promises';
import { constants as fsConstants } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

/**
 * Ensure the CLI bundle has a Node shebang and executable permissions.
 *
 * Usage: node ./scripts/ensure-cli.mjs
 */

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const cliPath = path.resolve(__dirname, '..', 'dist', 'main.mjs');

/**
 * Log an error and exit with non-zero status.
 * @param {string} message
 * @returns {never}
 */
const fail = (message) => {
  console.error(message);
  process.exit(1);
};

/**
 * Check whether a file exists and is accessible.
 * @param {string} file
 * @returns {Promise<boolean>}
 */
const exists = async (file) => {
  try {
    await fs.access(file, fsConstants.F_OK);
    return true;
  } catch {
    return false;
  }
};

/**
 * Ensure the file starts with a shebang. If missing, prepend it.
 * @param {string} file
 * @returns {Promise<void>}
 */
const ensureShebang = async (file) => {
  const content = await fs.readFile(file, 'utf8');
  if (!content.startsWith('#!')) {
    const updated = '#!/usr/bin/env node\n' + content;
    await fs.writeFile(file, updated, 'utf8');
    console.log(`Added shebang to ${file}`);
  } else {
    console.log(`Shebang already present in ${file}`);
  }
};

/**
 * Ensure the file is executable (mode 755). On platforms where this is a no-op,
 * this will not throw a fatal error.
 * @param {string} file
 * @returns {Promise<void>}
 */
const ensureExecutable = async (file) => {
  try {
    await fs.chmod(file, 0o755);
    console.log(`Set executable mode on ${file}`);
  } catch (err) {
    console.warn(`Warning: couldn't set executable bit on ${file}: ${err?.message ?? err}`);
  }
};

try {
  const found = await exists(cliPath);
  if (!found) {
    fail(`Prepare step failed: ${cliPath} not found. Did the bundle step succeed?`);
  }

  await ensureShebang(cliPath);
  await ensureExecutable(cliPath);

  console.log('CLI ensure step completed successfully.');
} catch (err) {
  console.error('Unexpected error in prepare script:', err?.message ?? err);
  process.exit(1);
}
