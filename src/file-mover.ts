import os from "os";
import { basename, join } from "path";
import { mkdir, rename } from "fs/promises";

class FileMover {
  private readonly destination: string;

  constructor(destination: string) {
    this.destination = destination;
  }

  async move(source: string) {
    const fileName = basename(source);

    try {
      await this.ensureDirectory();

      await rename(source, join(this.destination, fileName));

      console.log(`Moved to ${os.homedir()}/${this.destination}`);
    } catch (e) {
      console.log(e);
    }
  }

  async ensureDirectory() {
    await mkdir(this.destination, {
      recursive: true,
    });
  }
}

export default FileMover;
