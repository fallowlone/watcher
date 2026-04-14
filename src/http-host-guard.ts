const LOOPBACK = new Set(["127.0.0.1", "::1", "localhost", "::ffff:127.0.0.1"]);

function isNonLoopbackBinding(host: string): boolean {
  const h = host.trim().toLowerCase();
  if (h === "0.0.0.0" || h === "::" || h === "*" || h === "") return true;
  return !LOOPBACK.has(h);
}

/**
 * Exit unless FILESANDBOX_ALLOW_LAN=1 when binding HTTP to non-loopback.
 */
export function assertSafeHttpHost(host: string): void {
  if (!isNonLoopbackBinding(host)) return;
  const allow = process.env.FILESANDBOX_ALLOW_LAN?.trim() === "1";
  if (allow) {
    console.warn(
      `[security] HTTP bound to ${host} — API is reachable on the network. Set FILESANDBOX_API_TOKEN and never expose without reverse-proxy auth.`,
    );
    return;
  }
  console.error(
    `[security] Refusing to bind HTTP to ${host} (non-loopback). Set HTTP_HOST to 127.0.0.1 or set FILESANDBOX_ALLOW_LAN=1 if you accept the risk.`,
  );
  process.exit(1);
}
