import { watch } from "chokidar";
import { watch as fsWatch, chmod as fsChmod } from "fs";
import { cacheCheck, cacheStore } from "./vt-cache.ts";
import { chmod as chmodAsync } from "fs/promises";
import { execFile } from "child_process";
import { basename, join } from "path";
import { randomUUID } from "crypto";
import FileMover from "./file-mover.ts";
import FilePermissions from "./file-permissions.ts";
import VirusChecker from "./virus-checker.ts";
import type { JobStore } from "./job-store.ts";

// Best-effort: set com.apple.quarantine xattr so Gatekeeper blocks execution
// before the file enters the quarantine pipeline.
function setQuarantineXattr(filePath: string): Promise<void> {
  return new Promise((resolve) => {
    execFile(
      "xattr",
      ["-w", "com.apple.quarantine", "0083;00000000;FileSandbox;", filePath],
      () => resolve(),
    );
  });
}

// Browser incomplete-download temp extensions — never process these, only the
// final renamed file that appears after the download completes.
const BROWSER_TEMP_EXTENSIONS = [
  ".crdownload", // Chrome
  ".download", // Safari
  ".part", // Firefox
  ".opdownload", // Opera
  ".tmp", // generic
];

class Watcher {
  private readonly watchPath: string;
  private readonly ignored: string[];
  private filePermissions: FilePermissions;
  private fileMover: FileMover;
  private quarantinePath: string;
  private virusChecker: VirusChecker;
  private readonly jobStore?: JobStore;
  // Paths currently being restored — skip re-scan of just-restored clean files.
  private readonly restoringPaths = new Set<string>();
  private readonly scanControllers = new Map<string, AbortController>();

  constructor(
    watchPath: string,
    ignored: string[],
    quarantinePath: string,
    apiKey: string,
    jobStore?: JobStore,
  ) {
    this.quarantinePath = quarantinePath;
    this.watchPath = watchPath;
    this.ignored = ignored;

    this.fileMover = new FileMover(this.quarantinePath);
    this.virusChecker = new VirusChecker(apiKey);
    this.filePermissions = new FilePermissions();
    this.jobStore = jobStore;
  }

  cancel(jobId: string) {
    const controller = this.scanControllers.get(jobId);
    if (controller) {
      controller.abort();
      this.scanControllers.delete(jobId);
    }
  }

  start() {
    const stabilityThreshold = Number(process.env.WATCH_STABILITY_MS) || 2000;
    const pollInterval = Number(process.env.WATCH_POLL_MS) || 100;

    // fs.watch uses kqueue/FSEvents directly (~1–5ms vs chokidar's ~10ms).
    // Fires immediately on file appearance — no awaitWriteFinish delay.
    // Two-step lockdown: chmod 0o000 (no access for anyone) + quarantine xattr.
    // chmod 0o000 blocks execution AND reading before any other process can act.
    const isBrowserTemp = (filename: string) =>
      BROWSER_TEMP_EXTENSIONS.some((ext) => filename.endsWith(ext));

    const rawFsWatcher = fsWatch(
      this.watchPath,
      { recursive: false },
      (event, filename) => {
        if (!filename || event !== "rename") return;
        if ((this.ignored as string[]).some((ign) => filename.endsWith(ign)))
          return;
        if (isBrowserTemp(filename)) return;
        const fullPath = join(this.watchPath, filename);
        if (this.restoringPaths.has(fullPath)) return;
        fsChmod(fullPath, 0o000, () => {}); // fire-and-forget; ENOENT on delete events is silently ignored
        setQuarantineXattr(fullPath).catch(() => {});
      },
    );

    const watcher = watch(this.watchPath, {
      ignoreInitial: true,
      // Raw lockdown uses chmod 0o000 (no owner read bit). Chokidar's directory scan
      // drops files that fail _hasReadPermissions (requires mode & 0o400), so without
      // this flag "add" never fires and only the rename handler runs (chmod + xattr).
      ignorePermissionErrors: true,
      // Use a function so full paths are matched correctly (micromatch bare strings
      // don't match against full paths like /Users/.../Downloads/.DS_Store).
      ignored: (f: string) => this.ignored.some((ign) => f.endsWith(ign)),
      awaitWriteFinish: {
        stabilityThreshold,
        pollInterval,
      },
    });

    const handleFile = async (filepath: string) => {
      // Skip browser temp download files — chokidar still tracks them so that
      // FSEvents correctly fires "add" for the final renamed path, but we don't
      // quarantine the in-progress temp file itself.
      if (isBrowserTemp(filepath)) return;

      // Belt-and-suspenders: chokidar v5's function-based ignored is not always
      // applied before the event fires (observed with .DS_Store on macOS FSEvents).
      const fname = basename(filepath);
      if (this.ignored.some((ign) => fname === ign)) return;

      if (this.restoringPaths.has(filepath)) {
        this.restoringPaths.delete(filepath);
        return;
      }

      // Belt-and-suspenders: ensure quarantine xattr is set even if raw
      // watcher missed the event (e.g. file appeared during startup).
      await setQuarantineXattr(filepath);

      const jobId = randomUUID();
      this.jobStore?.insertReceived(jobId, filepath, basename(filepath));

      try {
        // Unlock to read-only so FileMover can copy to quarantine.
        // Was 0o000 from raw watcher lockdown — still no exec permission.
        await chmodAsync(filepath, 0o444).catch(() => {});

        const { quarantineFilePath, originalBaseName } =
          await this.fileMover.move(filepath);

        this.jobStore?.setInQuarantine(jobId, quarantineFilePath);

        await this.filePermissions.changePermissions(quarantineFilePath, 0o444);

        console.log(
          `Watching: path=${filepath} quarantine=${quarantineFilePath} originalName=${originalBaseName}`,
        );

        this.jobStore?.setScanning(jobId);

        // SHA-256 cache hit → skip VT upload entirely
        const cached = await cacheCheck(quarantineFilePath);
        if (cached) {
          console.log(`vt-cache hit: ${cached} (skipped upload)`);
          const result = {
            verdict: cached as import("./virus-checker.ts").VirusVerdict,
            message: `From local cache (SHA-256 match)`,
          };
          this.jobStore?.setScanResult(jobId, result);
          if (result.verdict === "clean") {
            const destPath = await this.fileMover.resolveRestoreDestination(
              this.watchPath,
              originalBaseName,
            );
            this.restoringPaths.add(destPath);
            const { restoredPath } = await this.fileMover.restoreToWatch(
              this.watchPath,
              quarantineFilePath,
              originalBaseName,
            );
            this.jobStore?.setRestored(jobId, restoredPath);
          }
          return;
        }

        const controller = new AbortController();
        this.scanControllers.set(jobId, controller);
        const result = await this.virusChecker.check(
          quarantineFilePath,
          controller.signal,
        );
        this.scanControllers.delete(jobId);

        if (result.verdict !== "inconclusive") {
          await cacheStore(quarantineFilePath, result.verdict);
        }
        console.log(`VirusTotal: ${result.verdict} — ${result.message}`);

        if (result.message === "Cancelled by user") {
          this.jobStore?.cancelJob(jobId);
          console.log(
            `Scan cancelled — keeping in quarantine: ${quarantineFilePath}`,
          );
          return;
        }

        this.jobStore?.setScanResult(jobId, result);

        if (result.verdict === "clean") {
          // Resolve destination before copying so we can register it in
          // restoringPaths before chokidar sees the new file appear.
          const destPath = await this.fileMover.resolveRestoreDestination(
            this.watchPath,
            originalBaseName,
          );
          this.restoringPaths.add(destPath);

          const { restoredPath } = await this.fileMover.restoreToWatch(
            this.watchPath,
            quarantineFilePath,
            originalBaseName,
          );
          this.jobStore?.setRestored(jobId, restoredPath);
        } else {
          console.log(
            `Keeping in quarantine (${result.verdict}): ${quarantineFilePath}`,
          );
        }
      } catch (error) {
        console.log(`Failed processing ${filepath}: ${error}`);
        this.jobStore?.fail(jobId, String(error));
      }
    };

    watcher.on("add", handleFile);
    watcher.on("change", handleFile);
    watcher.on("error", (error) => {
      console.log(`Watcher error: ${error}`);
    });

    return { watcher, rawFsWatcher };
  }
}

export default Watcher;
