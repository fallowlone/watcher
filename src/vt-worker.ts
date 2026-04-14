/**
 * Child entry: `node src/vt-worker.ts <absolutePath>`
 * Uses VT_API_KEY and MAX_SCAN_BYTES from the environment.
 */
import { virusCheckFile } from "./virus-checker.ts";

const filePath = process.argv[2];
const apiKey = process.env.VT_API_KEY ?? "";
const maxBytes = Number(process.env.MAX_SCAN_BYTES) || 400 * 1024 * 1024;

if (!filePath) {
  console.log(
    JSON.stringify({
      verdict: "inconclusive" as const,
      message: "vt-worker: missing file path",
    }),
  );
  process.exit(1);
}

virusCheckFile(apiKey, filePath, undefined, { maxBytes })
  .then((r) => {
    console.log(JSON.stringify(r));
  })
  .catch((e) => {
    console.log(
      JSON.stringify({
        verdict: "inconclusive" as const,
        message: String(e),
      }),
    );
    process.exit(1);
  });
