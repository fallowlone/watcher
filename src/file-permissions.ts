import type { Mode } from "fs";
import { chmod } from "fs/promises";

class FilePermissions {
  async changePermissions(filePath: string, mode: Mode) {
    try {
      await chmod(filePath, mode);
    } catch (error) {
      console.log(error);
    }
  }
}

export default FilePermissions;
