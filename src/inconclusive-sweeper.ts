import type { JobStore } from "./job-store.ts";

/**
 * Hourly purge of inconclusive quarantine jobs older than `retentionDays`.
 */
export function startInconclusiveSweeper(
  retentionDays: number,
  jobStore: JobStore,
  deleteQuarantined: (jobId: string) => Promise<void>,
): () => void {
  if (retentionDays <= 0) {
    return () => {};
  }

  const intervalMs = 60 * 60 * 1000;
  const maxAgeMs = retentionDays * 24 * 60 * 60 * 1000;

  const tick = async () => {
    const cutoff = Date.now() - maxAgeMs;
    const rows = jobStore.listInconclusiveOlderThan(cutoff);
    for (const row of rows) {
      try {
        await deleteQuarantined(row.id);
      } catch (e) {
        console.log(`Inconclusive sweeper skip ${row.id}: ${e}`);
      }
    }
  };

  const id = setInterval(() => {
    tick().catch((e) => console.log(`Inconclusive sweeper: ${e}`));
  }, intervalMs);
  tick().catch((e) => console.log(`Inconclusive sweeper: ${e}`));

  return () => clearInterval(id);
}
