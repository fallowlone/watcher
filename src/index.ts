import os from "os";
import path from "path";
import Watcher from "./watcher.ts";

const watchPath = path.join(os.homedir(), "Downloads");
const quarantinePath = path.join(os.homedir(), ".quarantine");

new Watcher(watchPath, [".DS_Store"], quarantinePath);
