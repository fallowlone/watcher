import fs, { type PathOrFileDescriptor } from "fs";
import { spawn } from "child_process";
import { dirname, join } from "path";
import { fileURLToPath } from "url";
import type { AnalysisResponse } from "./types/analysis.ts";

export type VirusVerdict = "clean" | "infected" | "inconclusive" | "oversized";

export interface VirusCheckResult {
  verdict: VirusVerdict;
  message: string;
  malicious?: number;
  suspicious?: number;
}

interface IVTUploadResponse {
  data?: {
    type: string;
    id: string;
  };
  error?: { code?: string; message?: string };
}

const apiUrl = "https://www.virustotal.com/api/v3";

export interface VirusCheckOptions {
  maxBytes: number;
}

/**
 * Core VT scan (same process). Respects maxBytes before reading whole file into RAM.
 */
export async function virusCheckFile(
  apiKey: string,
  path: PathOrFileDescriptor,
  signal: AbortSignal | undefined,
  opts: VirusCheckOptions,
): Promise<VirusCheckResult> {
  try {
    const st = fs.statSync(path);
    if (st.isFile() && st.size > opts.maxBytes) {
      return {
        verdict: "oversized",
        message: `File exceeds scan limit (${opts.maxBytes} bytes); not uploaded to VirusTotal. You can restore or delete from the UI.`,
      };
    }
  } catch {
    return {
      verdict: "inconclusive",
      message: "Failed to stat file before scan",
    };
  }

  let file: Buffer;
  try {
    file = fs.readFileSync(path);
  } catch {
    return {
      verdict: "inconclusive",
      message: "Failed to read file for upload",
    };
  }

  const formData = new FormData();
  formData.append("file", new Blob([file]));

  let request: Response;
  try {
    request = await fetch(apiUrl + "/files", {
      method: "POST",
      headers: {
        "x-apikey": apiKey,
      },
      body: formData,
      signal,
    });
  } catch (e) {
    if (e instanceof Error && e.name === "AbortError") {
      return { verdict: "inconclusive", message: "Cancelled by user" };
    }
    return {
      verdict: "inconclusive",
      message: `Upload network error: ${e}`,
    };
  }

  if (!request.ok) {
    const body = await request.text();
    return {
      verdict: "inconclusive",
      message: `Upload failed HTTP ${request.status}: ${body.slice(0, 500)}`,
    };
  }

  let uploadJson: IVTUploadResponse;
  try {
    uploadJson = (await request.json()) as IVTUploadResponse;
  } catch {
    return {
      verdict: "inconclusive",
      message: "Invalid JSON in upload response",
    };
  }

  if (uploadJson.error) {
    return {
      verdict: "inconclusive",
      message: `Upload API error: ${uploadJson.error.message ?? JSON.stringify(uploadJson.error)}`,
    };
  }

  const analysisId = uploadJson.data?.id;
  if (!analysisId) {
    return {
      verdict: "inconclusive",
      message: "No analysis id in upload response",
    };
  }

  const maxPolls = Number(process.env.VT_MAX_POLLS) || 20;
  const pollMs = Number(process.env.VT_POLL_INTERVAL_MS) || 15000;

  for (let i = 0; i < maxPolls; i++) {
    await new Promise((resolve) => setTimeout(resolve, pollMs));

    if (signal?.aborted) {
      return { verdict: "inconclusive", message: "Cancelled by user" };
    }

    let status: Response;
    try {
      status = await fetch(apiUrl + `/analyses/${analysisId}`, {
        method: "GET",
        headers: {
          "x-apikey": apiKey,
        },
        signal,
      });
    } catch (e) {
      if (e instanceof Error && e.name === "AbortError") {
        return { verdict: "inconclusive", message: "Cancelled by user" };
      }
      return {
        verdict: "inconclusive",
        message: `Analysis poll network error: ${e}`,
      };
    }

    if (!status.ok) {
      const body = await status.text();
      return {
        verdict: "inconclusive",
        message: `Analysis poll HTTP ${status.status}: ${body.slice(0, 500)}`,
      };
    }

    let parsed: AnalysisResponse;
    try {
      parsed = (await status.json()) as AnalysisResponse;
    } catch {
      return {
        verdict: "inconclusive",
        message: "Invalid JSON in analysis response",
      };
    }

    const { data } = parsed;
    const state = data.attributes.status;

    if (state === "queued" || state === "in-progress") {
      continue;
    }

    if (state === "completed") {
      const stats = data.attributes.stats;
      const malicious = stats.malicious ?? 0;
      const suspicious = stats.suspicious ?? 0;
      const harmless = stats.harmless ?? 0;
      const undetected = stats.undetected ?? 0;
      const total = malicious + harmless + undetected + suspicious;

      if (malicious > 0 || suspicious > 0) {
        return {
          verdict: "infected",
          message: `Threats: malicious=${malicious}, suspicious=${suspicious} (engines reporting: ${total})`,
          malicious,
          suspicious,
        };
      }

      return {
        verdict: "clean",
        message: `No malicious or suspicious flags (${total} engines with verdicts)`,
        malicious: 0,
        suspicious: 0,
      };
    }

    return {
      verdict: "inconclusive",
      message: `Unexpected analysis status: ${state}`,
    };
  }

  return {
    verdict: "inconclusive",
    message: `Polling timeout after ${maxPolls} attempts (${pollMs}ms interval)`,
  };
}

/**
 * Run VT scan in a fresh Node process (bytes read + network only in child).
 */
export function virusCheckInChildProcess(
  apiKey: string,
  filePath: string,
  signal: AbortSignal | undefined,
  maxBytes: number,
): Promise<VirusCheckResult> {
  return new Promise((resolve) => {
    const worker = join(
      dirname(fileURLToPath(import.meta.url)),
      "vt-worker.ts",
    );
    const child = spawn(process.execPath, [worker, filePath], {
      env: {
        ...process.env,
        VT_API_KEY: apiKey,
        MAX_SCAN_BYTES: String(maxBytes),
      },
      execArgv: [...process.execArgv],
      stdio: ["ignore", "pipe", "pipe"],
    });

    // Calculate timeout: max polling duration + 60s buffer
    const maxPolls = Number(process.env.VT_MAX_POLLS) || 20;
    const pollMs = Number(process.env.VT_POLL_INTERVAL_MS) || 15000;
    const timeoutMs = maxPolls * pollMs + 60_000;

    const timeoutId = setTimeout(() => {
      child.kill();
      resolve({
        verdict: "inconclusive",
        message: `VT child process timed out after ${timeoutMs}ms`,
      });
    }, timeoutMs);

    const onAbort = () => {
      child.kill("SIGTERM");
    };
    signal?.addEventListener("abort", onAbort);

    let out = "";
    let err = "";
    child.stdout?.on("data", (d: Buffer) => {
      out += d.toString();
    });
    child.stderr?.on("data", (d: Buffer) => {
      err += d.toString();
    });
    child.on("close", (code) => {
      clearTimeout(timeoutId);
      signal?.removeEventListener("abort", onAbort);
      try {
        const line = out.trim().split("\n").pop() ?? "";
        const r = JSON.parse(line) as VirusCheckResult;
        resolve(r);
      } catch {
        resolve({
          verdict: "inconclusive",
          message: `VT child exit ${code}: ${err.slice(0, 300)} ${out.slice(0, 300)}`,
        });
      }
    });
  });
}

export interface VirusCheckerOptions {
  maxScanBytes: number;
  useSeparateVtProcess: boolean;
}

class VirusChecker {
  private readonly apiKey: string;
  private readonly maxScanBytes: number;
  private readonly useSeparateVtProcess: boolean;

  constructor(apiKey: string, options?: Partial<VirusCheckerOptions>) {
    this.apiKey = apiKey;
    this.maxScanBytes = options?.maxScanBytes ?? 400 * 1024 * 1024;
    this.useSeparateVtProcess = options?.useSeparateVtProcess ?? false;
  }

  async check(
    path: PathOrFileDescriptor,
    signal?: AbortSignal,
  ): Promise<VirusCheckResult> {
    const opts = { maxBytes: this.maxScanBytes };
    if (this.useSeparateVtProcess && typeof path === "string") {
      return virusCheckInChildProcess(
        this.apiKey,
        path,
        signal,
        this.maxScanBytes,
      );
    }
    return virusCheckFile(this.apiKey, path, signal, opts);
  }
}

export default VirusChecker;
