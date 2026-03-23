import Watcher from "./watcher.ts";
import ConfigManager from "./config-manager.ts";

const config = new ConfigManager();
const { watchPath, quarantinePath } = config.getConfig();

new Watcher(watchPath, [".DS_Store"], quarantinePath);
