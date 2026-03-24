import { watch, type FSWatcher } from "chokidar";
import FileMover from "./file-mover.ts";
import FilePermissions from "./file-permissions.ts";
import { basename, join } from "path";
import VirusChecker from "./virus-checker.ts";

class Watcher {
  private readonly watchPath: string;
  private readonly ignored: string[];
  private filePermissions: FilePermissions;
  private fileMover: FileMover;
  private quarantinePath: string;
  private virusChecker: VirusChecker;

  constructor(
    watchPath: string,
    ignored: string[],
    quarantinePath: string,
    apiKey: string,
  ) {
    this.quarantinePath = quarantinePath;
    this.watchPath = watchPath;
    this.ignored = ignored;

    this.fileMover = new FileMover(this.quarantinePath);
    this.virusChecker = new VirusChecker(apiKey);
    this.filePermissions = new FilePermissions();
  }

  start() {
    const watcher = watch(this.watchPath, {
      ignoreInitial: true,
      ignored: this.ignored,
    });

    watcher.on("add", async (filepath, stats) => {
      const fileName = basename(filepath);

      try {
        await this.fileMover.move(filepath);

        await this.filePermissions.changePermissions(
          join(this.quarantinePath, fileName),
          0o444,
        );

        console.log(`
      Path: ${filepath}
      Filename: ${fileName}`);

        const result = await this.virusChecker.check(
          join(this.quarantinePath, fileName),
        );

        console.log(result);
      } catch (error) {
        console.log(`Failed to move ${filepath} to quarantine: ${error}`);
      }
    });
    watcher.on("error", (error) => {
      console.log(`Watcher error: ${error}`);
    });

    return watcher;
  }
}

export default Watcher;
