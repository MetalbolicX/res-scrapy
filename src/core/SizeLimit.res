/** Shared input-size cap for fetched response bytes and stdin (50 MiB). */
let maxInputBytes =
  50 * 1024 * 1024

/**
  * Whole-mebibyte caps keep the compact "N MB" form; every other size prints
  * its exact byte count, so a sub-MiB cap never renders as "0 MB".
  */
let describe = (bytes: int): string => {
  let bytesPerMib = 1024 * 1024
  if bytes >= bytesPerMib && mod(bytes, bytesPerMib) == 0 {
    `${Int.toString(bytes / bytesPerMib)} MB`
  } else {
    `${Int.toString(bytes)} bytes`
  }
}
