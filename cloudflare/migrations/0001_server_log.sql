-- Durable server log: one append-only row per API request, written by worker.js through
-- ctx.waitUntil (cloudflare/serverlog.js). Additive only; no existing table is touched.
-- Apply:  wrangler d1 execute chalk_db --remote --file cloudflare/migrations/0001_server_log.sql
-- Never holds: request bodies, passwords/passcodes, tokens, raw IPs, teacher-typed text.

CREATE TABLE IF NOT EXISTS server_log (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  ts              TEXT NOT NULL,      -- request start, ISO 8601 UTC with ms
  route           TEXT NOT NULL,      -- e.g. /turn, /tts, /telemetry_anon
  method          TEXT NOT NULL,
  status          INTEGER NOT NULL,   -- HTTP status returned (429 = rate limited, 401 = auth failed)
  latency_ms      INTEGER NOT NULL,
  worker_version  TEXT,               -- Cloudflare version id (version_metadata binding)
  user_id         TEXT,               -- learner id from a VERIFIED JWT (same as telemetry_events.user_id)
  anon_id         TEXT,               -- per-browser demo id (same as telemetry_anon_events.anon_id)
  session_id      TEXT,               -- client session id as sent
  locale          TEXT,
  persona         TEXT,
  move            TEXT,               -- teacher move tag
  input_mode      TEXT,               -- menu | free_text
  text_len        INTEGER,            -- length of teacher-typed text; the text itself is not stored
  diag            TEXT,               -- JSON: per-part source/rule/attempts/upstream/repaired + rejected model texts
  upstream_status TEXT,               -- first upstream (model provider) status in diag
  error           TEXT,               -- scrubbed error or note (e.g. rate_limited)
  country         TEXT,               -- Cloudflare request geo (coarse, as telemetry conn)
  colo            TEXT
);
CREATE INDEX IF NOT EXISTS server_log_ts_idx ON server_log(ts);
