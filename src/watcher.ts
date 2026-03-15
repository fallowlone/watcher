import { watch, type FSWatcher } from "chokidar";
import FileMover from "./file-mover.ts";
import FilePermissions from "./file-permissions.ts";
import { basename, join } from "path";

class Watcher {
  private readonly watchPath: string;
  private readonly ignored: string[];
  private watcher: FSWatcher | null = null;
  private filePermissions: FilePermissions;
  private fileMover: FileMover;
  private quarantinePath: string;

  constructor(watchPath: string, ignored: string[], quarantinePath: string) {
    this.quarantinePath = quarantinePath;
    this.watchPath = watchPath;
    this.ignored = ignored;

    this.fileMover = new FileMover(this.quarantinePath);
    this.filePermissions = new FilePermissions();

    this.watcher = this.start();
  }

  start() {
    const watcher = watch(this.watchPath, {
      ignoreInitial: true,
      ignored: this.ignored,
    });

    watcher.on("add", async (filepath, stats) => {
      const fileName = basename(filepath);

      await this.fileMover.move(filepath);

      await this.filePermissions.changePermissions(
        join(this.quarantinePath, fileName),
        0o444,
      );

      console.log(`
      Path: ${filepath}
      Filename: ${fileName}`);
    });

    return watcher;
  }
}

export default Watcher;
