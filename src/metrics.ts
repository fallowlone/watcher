export const metrics = {
  startedAt: Date.now(),
  activeScans: 0,
  lastError: null as string | null,
  setLastError(msg: string | null) {
    this.lastError = msg;
  },
  incScan() {
    this.activeScans++;
  },
  decScan() {
    this.activeScans = Math.max(0, this.activeScans - 1);
  },
};
