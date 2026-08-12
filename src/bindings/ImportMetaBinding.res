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
    var url = process.getBuiltinModule('node:url');
    var fs = process.getBuiltinModule('node:fs');
    var currentPath = url.fileURLToPath(import.meta.url);
    var invokedPath = process.argv[1];
    // Resolve npm .bin symlinks before comparing the invoked CLI path.
    var resolvedCurrent;
    var resolvedInvoked;
    try {
      resolvedCurrent = fs.realpathSync(currentPath);
      resolvedInvoked = fs.realpathSync(invokedPath);
    } catch (e) {
      resolvedCurrent = currentPath;
      resolvedInvoked = invokedPath;
    }
    return resolvedCurrent === resolvedInvoked;
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
