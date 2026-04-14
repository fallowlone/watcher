import { execFile } from "child_process";
import { join } from "path";

// Path to the compiled Rust binary — built via `cargo build --release` in vt-cache/
const BIN = join(process.cwd(), "vt-cache/target/release/vt-cache");

function run(args: string[]): Promise<string> {
  return new Promise((resolve) => {
    execFile(BIN, args, (_err, stdout) => resolve(stdout.trim()));
  });
}

/**
 * Check the local SHA-256 cache before uploading to VirusTotal.
 * Returns the cached verdict string, or null on miss / binary not found.
 */
export async function cacheCheck(filePath: string): Promise<string | null> {
  try {
    const result = await run(["check", filePath]);
    return result === "miss" || result === "" ? null : result;
  } catch {
    return null; // binary not built yet — silently skip cache
  }
}

/**
 * Persist a verdict for this file's SHA-256 hash.
 * Fire-and-forget — never throws.
 */
export async function cacheStore(
  filePath: string,
  verdict: string,
): Promise<void> {
  try {
    await run(["store", filePath, verdict]);
  } catch {
    // binary not available — silently skip
  }
}
