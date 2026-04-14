import Watcher from "./watcher.ts";
import { JobStore } from "./job-store.ts";
import { startUiServer } from "./ui-server.ts";
import { startLaunchAgentMonitor } from "./launch-agent-monitor.ts";
import { config } from "./config.ts";
import FileMover from "./file-mover.ts";

if (!config.vtApiKey)
  throw new Error("vtApiKey not set (config.json or VT_API_KEY)");
if (!config.watchPath)
  throw new Error("watchPath not set (config.json or WATCH_PATH)");
if (!config.quarantinePath)
  throw new Error("quarantinePath not set (config.json or QUARANTINE_PATH)");

const jobStore = new JobStore(config.databasePath);
const fileMover = new FileMover(config.quarantinePath);

const watcher = new Watcher(
  config.watchPath,
  [".DS_Store"],
  config.quarantinePath,
  config.vtApiKey,
  jobStore,
);
watcher.start();
startLaunchAgentMonitor();

if (config.httpPort !== undefined) {
  startUiServer(
    jobStore,
    config.httpPort,
    (id) => watcher.cancel(id),
    async (id) => {
      const job = jobStore.getJob(id);
      if (!job) throw new Error(`Job ${id} not found`);
      if (job.status !== "quarantine_kept")
        throw new Error(`Job ${id} is not in quarantine_kept status`);
      if (!job.quarantine_path)
        throw new Error(`Job ${id} has no quarantine path`);
      await fileMover.deleteFile(job.quarantine_path);
      jobStore.setDeleted(id);
    },
  );
}

function shutdown() {
  jobStore.close();
  process.exit(0);
}

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
