import express from "express";
import type { JobStore } from "./job-store.ts";
import { config, writeConfig } from "./config.ts";

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

export function startUiServer(
  store: JobStore,
  port: number,
  cancelJob?: (id: string) => void,
  deleteQuarantinedFile?: (id: string) => Promise<void>,
) {
  const host = process.env.HTTP_HOST ?? "127.0.0.1";
  const app = express();
  app.use(express.json());

  app.get("/api/jobs", (_req, res) => {
    try {
      res.json({ jobs: store.listRecent(200) });
    } catch (e) {
      res.status(500).json({ error: String(e) });
    }
  });

  app.delete("/api/jobs", (_req, res) => {
    try {
      store.clearAll();
      res.json({ ok: true });
    } catch (e) {
      res.status(500).json({ error: String(e) });
    }
  });

  app.post("/api/jobs/:id/cancel", (req, res) => {
    try {
      const { id } = req.params;
      cancelJob?.(id);
      res.json({ ok: true });
    } catch (e) {
      res.status(500).json({ error: String(e) });
    }
  });

  app.get("/api/config", (_req, res) => {
    res.json({
      vtApiKey: config.vtApiKey,
      watchPath: config.watchPath,
      quarantinePath: config.quarantinePath,
      databasePath: config.databasePath,
      httpPort: config.httpPort !== undefined ? String(config.httpPort) : "",
      httpHost: config.httpHost,
    });
  });

  app.post("/api/config", (req, res) => {
    try {
      const body = req.body as Record<string, string>;
      const updates: Record<string, string | number> = {};
      // Only persist non-empty values — prevents a failed settings fetch
      // from wiping real config when the user saves blank fields.
      if (body.vtApiKey) updates.vtApiKey = body.vtApiKey;
      if (body.watchPath) updates.watchPath = body.watchPath;
      if (body.quarantinePath) updates.quarantinePath = body.quarantinePath;
      if (body.databasePath) updates.databasePath = body.databasePath;
      if (body.httpHost) updates.httpHost = body.httpHost;
      if (body.httpPort) {
        const n = Number(body.httpPort);
        if (Number.isFinite(n) && n >= 1 && n <= 65535) updates.httpPort = n;
      }
      writeConfig(updates);
      res.json({ ok: true, restartRequired: true });
    } catch (e) {
      res.status(500).json({ error: String(e) });
    }
  });

  app.delete("/api/jobs/:id/quarantine", async (req, res) => {
    try {
      const { id } = req.params;
      if (!deleteQuarantinedFile) {
        res.status(501).json({ error: "delete not configured" });
        return;
      }
      await deleteQuarantinedFile(id);
      res.json({ ok: true });
    } catch (e) {
      res.status(500).json({ error: String(e) });
    }
  });

  app.get("/", (_req, res) => {
    const jobs = store.listRecent(200);
    const rows = jobs
      .map((j) => {
        const deleteBtn =
          j.status === "quarantine_kept"
            ? `<button onclick="deleteFile('${escapeHtml(j.id)}')">Delete</button>`
            : "";
        return `<tr><td>${escapeHtml(j.id.slice(0, 8))}…</td><td>${escapeHtml(j.original_name)}</td><td>${escapeHtml(j.status)}</td><td>${j.vt_verdict ? escapeHtml(j.vt_verdict) : "—"}</td><td title="${escapeHtml(j.detail ?? "")}">${escapeHtml((j.detail ?? "").slice(0, 80))}${(j.detail?.length ?? 0) > 80 ? "…" : ""}</td><td>${escapeHtml(j.final_path ?? "—")}</td><td>${deleteBtn}</td></tr>`;
      })
      .join("");

    res.type("html").send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>file-sandbox jobs</title>
  <style>
    body { font-family: system-ui, sans-serif; margin: 1rem; background: #111; color: #e6e6e6; }
    table { border-collapse: collapse; width: 100%; font-size: 14px; }
    th, td { border: 1px solid #333; padding: 6px 8px; text-align: left; vertical-align: top; }
    th { background: #1a1a1a; }
    tr:nth-child(even) { background: #161616; }
    h1 { font-size: 1.1rem; }
    a { color: #8cb4ff; }
  </style>
</head>
<body>
  <h1>Quarantine / VirusTotal job queue</h1>
  <p><a href="/api/jobs">JSON</a> · auto-refresh 15s</p>
  <table>
    <thead><tr><th>id</th><th>file</th><th>status</th><th>VT</th><th>detail</th><th>final path</th><th>actions</th></tr></thead>
    <tbody>${rows || "<tr><td colspan=6>no jobs yet</td></tr>"}</tbody>
  </table>
  <script>
    setTimeout(() => location.reload(), 15000);
    async function deleteFile(id) {
      if (!confirm('Permanently delete quarantined file?')) return;
      const res = await fetch('/api/jobs/' + id + '/quarantine', { method: 'DELETE' });
      const data = await res.json();
      if (data.ok) location.reload();
      else alert('Error: ' + data.error);
    }
  </script>
</body>
</html>`);
  });

  app.listen(port, host, () => {
    console.log(`UI http://${host}:${port}/`);
  });
}
