import Watcher from "./watcher.ts";
import ConfigManager from "./config-manager.ts";

const config = new ConfigManager();
const { watchPath, quarantinePath } = config.getConfig();

const apiKey = process.env.VT_API_KEY;
if (!apiKey) {
  throw new Error("VT_API_KEY is not set");
}

new Watcher(watchPath, [".DS_Store"], quarantinePath, apiKey).start();
