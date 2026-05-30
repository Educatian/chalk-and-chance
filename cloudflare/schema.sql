-- Chalk & Chance — all-Cloudflare per-learner identity + ECD data (D1 / SQLite).
-- Replaces the Supabase plan: auth + storage both live in one Worker + D1.
-- Pattern: fixed NAMED ACCOUNTS + class join code (like Design Tension Studio / cat531).
-- Apply:  wrangler d1 execute chalk_db --file cloudflare/schema.sql   (or --remote)

CREATE TABLE IF NOT EXISTS classes (
  class_code TEXT PRIMARY KEY,            -- e.g. 'UA-CAT531-SUMMER26'
  name       TEXT NOT NULL,
  join_open  INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS learners (
  user_id      TEXT PRIMARY KEY,          -- uuid-ish (worker-generated)
  class_code   TEXT NOT NULL REFERENCES classes(class_code),
  login_name   TEXT NOT NULL,             -- lowercased name used at login
  display_name TEXT NOT NULL,
  pw_hash      TEXT NOT NULL,             -- PBKDF2(password, salt)
  pw_salt      TEXT NOT NULL,
  role         TEXT NOT NULL DEFAULT 'learner',   -- 'learner' | 'instructor'
  created_at   TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (class_code, login_name)
);

-- One row per telemetry turn/event; event is the full JSON line from Telemetry.gd.
CREATE TABLE IF NOT EXISTS telemetry_events (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id      TEXT NOT NULL REFERENCES learners(user_id),
  session_id   TEXT NOT NULL,
  construct_id TEXT,
  event        TEXT NOT NULL,             -- JSON
  created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS tel_user_idx ON telemetry_events(user_id);
CREATE INDEX IF NOT EXISTS tel_sess_idx ON telemetry_events(session_id);

-- Per-IP rate limit counters for the paid endpoints (/turn, /tts cost guard).
CREATE TABLE IF NOT EXISTS rate_limits (
  k   TEXT PRIMARY KEY,
  n   INTEGER NOT NULL DEFAULT 0,
  exp INTEGER NOT NULL
);

-- Current ECD competency estimate (multivariate-Elo theta) per learner+skill.
CREATE TABLE IF NOT EXISTS competency (
  user_id    TEXT NOT NULL REFERENCES learners(user_id),
  skill      TEXT NOT NULL,
  theta      REAL NOT NULL DEFAULT 0,
  prob       REAL NOT NULL DEFAULT 0.5,
  n          INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (user_id, skill)
);
