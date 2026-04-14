import Watcher from "./watcher.ts";
import { JobStore } from "./job-store.ts";
import { startUiServer } from "./ui-server.ts";
import { startLaunchAgentMonitor } from "./launch-agent-monitor.ts";
import { config } from "./config.ts";

if (!config.vtApiKey)
  throw new Error("vtApiKey not set (config.json or VT_API_KEY)");
if (!config.watchPath)
  throw new Error("watchPath not set (config.json or WATCH_PATH)");
if (!config.quarantinePath)
  throw new Error("quarantinePath not set (config.json or QUARANTINE_PATH)");

const jobStore = new JobStore(config.databasePath);

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
  startUiServer(jobStore, config.httpPort, (id) => watcher.cancel(id));
}

function shutdown() {
  jobStore.close();
  process.exit(0);
}

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
