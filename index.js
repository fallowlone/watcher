import os from "os";
import path from "path";
import { watch } from "chokidar";
import { mkdir, rename, chmod } from "fs/promises";

const watchPath = path.join(os.homedir(), "Downloads");
console.log("Watching:", watchPath);

const watcher = watch(path.join(os.homedir(), "Downloads"), {
  ignoreInitial: true,
  ignored: (filepath, stats) => path.basename(filepath).startsWith("."),
});

watcher.on("add", async (filepath, stats) => {
  const fileName = path.basename(filepath);

  console.log(`
  Path: ${filepath}
  Filename: ${fileName}`);

  moveToQuarantine(filepath);
});

async function moveToQuarantine(filepath) {
  try {
    const fileName = path.basename(filepath);
    const quarantinePath = path.join(os.homedir(), ".quarantine", "pending");
    await mkdir(quarantinePath, {
      recursive: true,
    });
    await rename(filepath, path.join(quarantinePath, fileName));

    await chmod(path.join(quarantinePath, fileName), 0o444);
    console.log("chmod applied to:", path.join(quarantinePath, fileName));
    console.log(`Moved to ${os.homedir()}/.quarantine/pending`);
  } catch (error) {
    console.log(error);
  }
}

console.log("Watching...");
