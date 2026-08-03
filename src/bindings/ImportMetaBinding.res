/**
  * Bindings to ESM `import.meta.url` for module-relative path resolution.
  *
  * Used to locate package.json for version detection and other
  * module-relative resource lookups.
  */
/** Checks whether this script is executed directly (not imported as a module). */
let isExecutedAsScript: unit => bool = %raw(`function() {
  try {
    if (typeof process === "undefined" || !process.argv || process.argv.length < 2) {
      return false;
    }
    var currentPath = new URL(import.meta.url).pathname;
    var invokedPath = process.argv[1];
    return currentPath === invokedPath || decodeURIComponent(currentPath) === invokedPath;
  } catch (e) {
    return false;
  }
}`)

/** Returns an array of candidate package.json paths relative to the current module. */
let candidatePackagePaths: unit => array<string> = %raw(`function() {
  try {
    return [
      decodeURIComponent(new URL('../package.json', import.meta.url).pathname),
      decodeURIComponent(new URL('../../package.json', import.meta.url).pathname),
    ];
  } catch (e) {
    return [];
  }
}`)
