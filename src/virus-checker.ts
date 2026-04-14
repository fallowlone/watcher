import fs, { type PathOrFileDescriptor } from "fs";
import type { AnalysisResponse } from "./types/analysis.ts";

export type VirusVerdict = "clean" | "infected" | "inconclusive";

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

class VirusChecker {
  private readonly apiKey: string;
  private readonly apiUrl = "https://www.virustotal.com/api/v3";

  constructor(apiKey: string) {
    this.apiKey = apiKey;
  }

  async check(
    path: PathOrFileDescriptor,
    signal?: AbortSignal,
  ): Promise<VirusCheckResult> {
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
      request = await fetch(this.apiUrl + "/files", {
        method: "POST",
        headers: {
          "x-apikey": this.apiKey,
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
        status = await fetch(this.apiUrl + `/analyses/${analysisId}`, {
          method: "GET",
          headers: {
            "x-apikey": this.apiKey,
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
}

export default VirusChecker;
