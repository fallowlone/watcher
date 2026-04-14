# Security hardening (macOS Seatbelt, Linux seccomp, egress, split)

Threat-model gaps the app does **not** mitigate (same-UID trust, HTTP surface, VT limits, races, etc.) are summarized in [security-gaps.md](security-gaps.md) (RU).

## Conflict: strict isolation vs VirusTotal

Process that **uploads bytes to VirusTotal needs outbound HTTPS**. A container or process with **literally no egress** cannot call the VT API from the same runtime. Practical patterns:

1. **Single process (this repo default)** — watcher reads quarantined file, POSTs to VT. Isolation = separate FS path + `chmod` + no execution of samples. Egress exists for Node only.
2. **Split (stronger)** — **Stage A (no network):** move file to quarantine, optional hash/locally safe transforms, append row to shared DB. **Stage B (network):** separate service/user/container reads quarantine path from DB, uploads to VT, writes verdict. Malware in file never touches the network-capable stage unless that stage reads bytes (it still does not _execute_ the sample).
3. **Egress allowlist** — Linux: iptables/nftables or Cilium policy allowing only `www.virustotal.com:443` from the uploader. Docker alone does not provide fine-grained DNS allowlists; use orchestration or host firewall.

## macOS Seatbelt (App Sandbox)

Node.js has **no supported first-class Seatbelt API**. Options:

- **Don’t execute** the watched files; keep current model (data-only quarantine).
- **Small native helper** (Swift/ObjC) that calls `sandbox_init` and only passes file descriptors/paths according to entitlements — out of scope for this TypeScript repo but the right place for true sandbox rules.
- Historical `sandbox-exec` CLI is **not a supported path** on current macOS for new designs.

## Linux seccomp

Docker’s **default seccomp profile** already blocks many dangerous syscalls. Tightening further for Node + `better-sqlite3` + `fetch` is brittle (allow-list must include `epoll`, `futex`, socket syscalls, etc.).

Recommended steps:

- Use **`security_opt: [no-new-privileges:true]`** and **`cap_drop: [ALL]`** (see `docker-compose.yml`).
- Optionally pass a **custom seccomp JSON** only after auditing with your kernel and Node version:  
  `docker run --security-opt seccomp=/path/to/profile.json ...`

## Container “no egress” for the sample

If the **ingest** container has `--network none`, it cannot talk to VT. Use **split** (above): ingest container writes to a **shared volume**; **uploader** container has network and only reads files that are already in quarantine.

## UI / DB / queue

- SQLite (`DATABASE_PATH`) is the **durable job log** for the UI and ops.
- Bind UI to **localhost** or behind reverse proxy with auth if exposed.
- Do not expose VT API keys in the UI or client-side code.
