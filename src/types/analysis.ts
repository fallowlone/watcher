export type AnalysisCategory =
  | "confirmed-timeout"
  | "timeout"
  | "failure"
  | "harmless"
  | "undetected"
  | "suspicious"
  | "malicious"
  | "type-unsupported";

export type AnalysisStatus = "completed" | "queued" | "in-progress";

export interface AnalysisEngineResult {
  category: AnalysisCategory;
  engine_name: string;
  engine_version?: string;
  engine_update?: string;
  method: string;
  result: string | null;
}

export type AnalysisResults = Record<string, AnalysisEngineResult>;

export interface AnalysisStats {
  "confirmed-timeout": number;
  failure: number;
  harmless: number;
  malicious: number;
  suspicious: number;
  timeout: number;
  "type-unsupported": number;
  undetected: number;
}

interface BaseAttributes {
  date: number; // unix timestamp
}

export interface AnalysisQueuedAttributes extends BaseAttributes {
  status: "queued";
  results: Record<string, never>;
  stats: Record<string, never>;
}

export interface AnalysisInProgressAttributes extends BaseAttributes {
  status: "in-progress";
  results: AnalysisResults;
  stats: Partial<AnalysisStats>;
}

export interface AnalysisCompletedAttributes extends BaseAttributes {
  status: "completed";
  results: AnalysisResults;
  stats: AnalysisStats;
}

export type AnalysisAttributes =
  | AnalysisQueuedAttributes
  | AnalysisInProgressAttributes
  | AnalysisCompletedAttributes;

export interface AnalysisData {
  id: string;
  type: "analysis";
  attributes: AnalysisAttributes;
}

export interface AnalysisResponse {
  data: AnalysisData;
}
