import os from "os";
import path from "path";
import Watcher from "./watcher.ts";

const watchPath = path.join(os.homedir(), "Downloads");

new Watcher(watchPath, [".DS_Store"], ".quarantine");
