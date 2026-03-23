import os from "os";
import { readFileSync, existsSync, writeFileSync, mkdirSync } from "fs";

interface IConfigManager {
  watchPath: string;
  quarantinePath: string;
}

const defaultConfig: IConfigManager = {
  watchPath: os.homedir() + "/Downloads",
  quarantinePath: os.homedir() + "/Downloads/quarantine",
};

const CONFIG_PATH = os.homedir() + "/.file-sandbox/config.json";

class ConfigManager {
  private readonly configPath = CONFIG_PATH;
  private config!: IConfigManager;

  constructor() {
    this.loadConfig();
  }

  updateWatchPath(watchPath: string) {
    this.config.watchPath = watchPath;
    writeFileSync(this.configPath, JSON.stringify(this.config));
  }

  updateQuarantinePath(quarantinePath: string) {
    this.config.quarantinePath = quarantinePath;
    writeFileSync(this.configPath, JSON.stringify(this.config));
  }

  getConfig(): IConfigManager {
    return this.config;
  }

  loadConfig() {
    if (!existsSync(this.configPath)) {
      mkdirSync(os.homedir() + "/.file-sandbox", { recursive: true });
      writeFileSync(this.configPath, JSON.stringify(defaultConfig));
    }

    this.config = JSON.parse(
      readFileSync(this.configPath, "utf8"),
    ) as IConfigManager;
  }
}

export default ConfigManager;
