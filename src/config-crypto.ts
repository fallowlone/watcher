import {
  createCipheriv,
  createDecipheriv,
  randomBytes,
  scryptSync,
} from "crypto";

const PREFIX = "FSENC1:";

function parseMasterKey(raw: string): Buffer {
  const t = raw.trim();
  if (/^[0-9a-fA-F]{64}$/.test(t)) return Buffer.from(t, "hex");
  const b = Buffer.from(t, "base64");
  if (b.length === 32) return b;
  throw new Error(
    "FILESANDBOX_MASTER_KEY must be 64 hex chars (32 bytes) or base64 of 32 bytes",
  );
}

function deriveKey(master: Buffer, salt: Buffer): Buffer {
  return scryptSync(master, salt, 32);
}

/** Encrypt plaintext; returns PREFIX + base64(salt|iv|tag|ciphertext). */
export function encryptConfigJson(
  plaintext: string,
  masterKeyRaw: string,
): string {
  const master = parseMasterKey(masterKeyRaw);
  const salt = randomBytes(16);
  const key = deriveKey(master, salt);
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key, iv);
  const enc = Buffer.concat([cipher.update(plaintext, "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();
  const payload = Buffer.concat([salt, iv, tag, enc]);
  return PREFIX + payload.toString("base64");
}

/** Decrypt blob written by encryptConfigJson; throws on bad key or tamper. */
export function decryptConfigJson(blob: string, masterKeyRaw: string): string {
  if (!blob.startsWith(PREFIX)) {
    throw new Error("Encrypted config must start with FSENC1:");
  }
  const master = parseMasterKey(masterKeyRaw);
  const raw = Buffer.from(blob.slice(PREFIX.length), "base64");
  if (raw.length < 16 + 12 + 16 + 1)
    throw new Error("Encrypted config truncated");
  const salt = raw.subarray(0, 16);
  const iv = raw.subarray(16, 28);
  const tag = raw.subarray(28, 44);
  const data = raw.subarray(44);
  const key = deriveKey(master, salt);
  const decipher = createDecipheriv("aes-256-gcm", key, iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(data), decipher.final()]).toString(
    "utf8",
  );
}

export function isEncryptedConfigPayload(s: string): boolean {
  return s.trimStart().startsWith(PREFIX);
}
