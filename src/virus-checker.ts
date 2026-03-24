import fs, { type PathOrFileDescriptor } from "fs";
import type { AnalysisResponse } from "./types/analysis.ts";
interface IVTResponse {
  data: {
    type: "analysis";
    id: "string";
  };
}
class VirusChecker {
  private readonly apiKey: string;
  private readonly apiUrl = "https://www.virustotal.com/api/v3";

  constructor(apiKey: string) {
    this.apiKey = apiKey;
  }

  async check(path: PathOrFileDescriptor) {
    const file = fs.readFileSync(path);

    const formData = new FormData();
    formData.append("file", new Blob([file]));

    const request = await fetch(this.apiUrl + "/files", {
      method: "POST",
      headers: {
        "x-apikey": this.apiKey,
      },
      body: formData,
    });

    const response = (await request.json()) as IVTResponse;

    while (true) {
      const status = await fetch(this.apiUrl + `analyses/${response.data.id}`);

      const { data } = (await status.json()) as AnalysisResponse;

      const malicious = data.attributes.stats.malicious ?? 0;
      const harmless = data.attributes.stats.harmless ?? 0;
      const undetected = data.attributes.stats.undetected ?? 0;
      const total = malicious + harmless + undetected;

      if (data.attributes.status === "completed") {
        return `Threats identified: ${malicious} out of ${total}.`;
      }

      await new Promise((resolve) => setTimeout(resolve, 15000));
    }
  }
}

export default VirusChecker;
