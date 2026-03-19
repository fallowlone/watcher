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
  private config: IConfigManager | null = null;

  constructor() {
    this.loadConfig();
  }

  updateWatchPath(watchPath: string) {
    if (this.config) {
      this.config.watchPath = watchPath;
      writeFileSync(this.configPath, JSON.stringify(this.config));
    }
  }

  updateQuarantinePath(quarantinePath: string) {
    if (this.config) {
      this.config.quarantinePath = quarantinePath;
      writeFileSync(this.configPath, JSON.stringify(this.config));
    }
  }

  getConfig(): IConfigManager {
    if (this.config) {
      return this.config;
    }

    return defaultConfig;
  }

  loadConfig() {
    if (this.config) {
      return;
    }

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
