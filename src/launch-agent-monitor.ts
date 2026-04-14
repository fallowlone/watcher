import { watch } from "chokidar";
import { homedir } from "os";
import { join } from "path";

const AGENT_PATHS = [
  join(homedir(), "Library/LaunchAgents"),
  "/Library/LaunchAgents",
  "/Library/LaunchDaemons",
];

export function startLaunchAgentMonitor(): ReturnType<typeof watch> {
  const watcher = watch(AGENT_PATHS, {
    ignoreInitial: true,
    ignored: [/\.DS_Store/, /[/\\]\./],
    depth: 0,
  });

  watcher.on("add", (filePath: string) => {
    console.warn(`[SECURITY] New launch agent registered: ${filePath}`);
  });

  watcher.on("change", (filePath: string) => {
    console.warn(`[SECURITY] Launch agent modified: ${filePath}`);
  });

  watcher.on("unlink", (filePath: string) => {
    console.log(`[SECURITY] Launch agent removed: ${filePath}`);
  });

  watcher.on("error", (err: Error) => {
    console.error(`[SECURITY] Launch agent monitor error: ${err.message}`);
  });

  console.log(
    `[SECURITY] Watching launch agent dirs: ${AGENT_PATHS.join(", ")}`,
  );
  return watcher;
}
