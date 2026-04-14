import { readFileSync, writeFileSync } from "fs";
import { join } from "path";

interface RawConfig {
  vtApiKey?: string;
  watchPath?: string;
  quarantinePath?: string;
  databasePath?: string;
  httpPort?: number;
  httpHost?: string;
}

const configPath = join(process.cwd(), "config.json");

function load(): RawConfig {
  try {
    const raw = readFileSync(configPath, "utf8");
    return JSON.parse(raw) as RawConfig;
  } catch {
    return {};
  }
}

const file = load();

function get(fileVal: string | undefined, envVal: string | undefined): string {
  return fileVal ?? envVal ?? "";
}

export function writeConfig(updates: Partial<RawConfig>): void {
  let existing: RawConfig = {};
  try {
    existing = JSON.parse(readFileSync(configPath, "utf8")) as RawConfig;
  } catch {}
  const merged = { ...existing, ...updates };
  writeFileSync(configPath, JSON.stringify(merged, null, 2), "utf8");
}

export const config = {
  vtApiKey: get(file.vtApiKey, process.env.VT_API_KEY),
  watchPath: get(file.watchPath, process.env.WATCH_PATH),
  quarantinePath: get(file.quarantinePath, process.env.QUARANTINE_PATH),
  databasePath:
    file.databasePath ?? process.env.DATABASE_PATH ?? "./data/jobs.sqlite",
  httpPort: (() => {
    const raw = file.httpPort ?? process.env.HTTP_PORT;
    if (raw === undefined || raw === "") return undefined;
    const n = Number(raw);
    if (!Number.isFinite(n) || n < 1 || n > 65535)
      throw new Error("httpPort must be 1–65535");
    return n;
  })(),
  httpHost: file.httpHost ?? process.env.HTTP_HOST ?? "127.0.0.1",
};
