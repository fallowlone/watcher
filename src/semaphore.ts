/** Simple async semaphore for limiting concurrent VT scans. */
export class Semaphore {
  private available: number;
  private readonly waiters: (() => void)[] = [];

  constructor(permits: number) {
    this.available = Math.max(1, permits);
  }

  async acquire(): Promise<void> {
    if (this.available > 0) {
      this.available--;
      return;
    }
    await new Promise<void>((resolve) => this.waiters.push(resolve));
  }

  release(): void {
    const next = this.waiters.shift();
    if (next) next();
    else this.available++;
  }
}
