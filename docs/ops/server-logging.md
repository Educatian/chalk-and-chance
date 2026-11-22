# Durable server logs (D1 `server_log` → R2 archive → off-Cloudflare copy)

The owner's requirement (2026-11-22) is that logs are kept permanently. This page records what is already stored durably, what was lost before this change, the design that was built, and what the owner still has to do.

## 1. Inventory: what D1 (`chalk_db`) keeps today

| table | one row is | holds | kept |
|---|---|---|---|
| `classes` | a class | `class_code`, name, `join_open`, created_at | forever |
| `learners` | a named account | `user_id` (Worker uuid), class, login/display name, PBKDF2 hash + salt, role | forever |
| `telemetry_events` | one game event of a signed-in learner | `user_id` (from the verified JWT), `session_id`, `construct_id`, `event` = the whole sanitised event JSON | forever |
| `telemetry_anon_events` | one game event of demo / not-signed-in play | `anon_id` (per-browser random id from the client, e.g. `a_1795346350_509200`), `session_id`, `construct_id`, `event` JSON | forever |
| `competency` | current skill estimate per learner + skill | theta, prob, n, updated_at (overwritten, not appended) | latest only |
| `rate_limits` | a per-IP counter window | key `bucket:<ip-hash>:window:slot`, where `<ip-hash>` is HMAC-SHA256 of the IP with `WORKER_SECRET` (16 base64url chars; no raw IP since the follow-up PR), count, expiry | ≤ 1 hour; pruned at random |

The `event` JSON is full fidelity, clamped to 600 characters per string and 8 KB per event:
- dialogue text, including **teacher-typed free text** (`move.text`);
- student replies, input keys and choices;
- on `session_start`, the connection context `conn`: country, city, region, colo, timezone, AS org, referer, user agent, Accept-Language. There is no raw IP.

### What was not stored anywhere durable before this change
The Worker has no `[observability]`, so `console.log` lines vanish.

| lost | where it existed |
|---|---|
| `/turn`, `/group_turn`, `/lecture_turn` diag: source, rule, attempts, upstream status and retries, repaired | only in the HTTP response |
| rejected model texts | only in a debug response (`x-cc-diag: 1`) |
| latency per request | nowhere |
| HTTP status and errors (500s with the exception text) | response only |
| rate-limit hits (429) | counters only, gone within the hour |
| auth failures (401 on login, `/me`, `/telemetry`; 403 on `/voice_token`) | response only |
| `/tts` and `/voice_token` calls | nowhere |
| which Worker version answered | nowhere |

"Import" happens only in the client: lesson plans are parsed in the game. No import route exists in the Worker, so there was nothing to log.

### Size
- The DB is **~183 MB**, as the coordinator reported.
- D1 limits ([Cloudflare D1 limits](https://developers.cloudflare.com/d1/platform/limits/)) are **10 GB per database on Workers Paid**, a fixed cap that cannot be raised, and **500 MB on the Free plan**. On Free, inserts stop once the database is full.
- The repo does not record the plan. **If the account is on Free, the database is already at about 37% of its cap**, and the R2 archive with pruning matters much sooner.

## 2. `server_log`: built in this PR
- **Migration:** `cloudflare/migrations/0001_server_log.sql`. It is additive (`CREATE TABLE IF NOT EXISTS` plus an index on `ts`) and touches no existing table.
- **Code:** `cloudflare/serverlog.js` and `worker.js`.
- **One row per API request.** Every route is logged, including 404s, 401s, 429s and 500s. Only CORS `OPTIONS` preflights are skipped.
- **Columns:** `ts` (UTC, ms), route, method, status, latency_ms, worker_version, user_id, anon_id, session_id, locale, persona, move, input_mode, text_len, diag (JSON), upstream_status, error, country, colo.
- **Written after the response** through `ctx.waitUntil`. Every error in the log path is swallowed, so **a failed log write never fails or changes a request**. This holds even before the migration is applied (tested).
- **Identifiers follow the existing telemetry practice and add no new ones:**
  - `user_id` comes only from a **verified** JWT, the same id as `telemetry_events.user_id`. An invalid token logs no id; the 401 status shows the failure.
  - `anon_id` is the per-browser id the client already sends to `/telemetry_anon`. Since the follow-up PR, the client also sends it on `/turn`, `/group_turn` and `/lecture_turn`, normalised the same way, so rows join to `telemetry_anon_events`.
  - `session_id` is taken as the client sends it.
  - Location is country and Cloudflare colo, which is coarser than telemetry's `conn`.
- **LLM routes (follow-up PR):** the client sends the telemetry `session_id` (it used to send the constants `m1` / `grp` / `gym` / `lecture`) and, for demo play, its `anon_id`. A signed-in learner sends the JWT instead, and the row gets the verified `user_id`. Nothing in the Worker or the local backend keyed on the old constants; they were only echoed back.
- **Never stored:**
  - request bodies, passwords and passcodes, JWTs, voice tokens, Authorization / X-Voice-Token headers, raw IPs;
  - the bodies of `/auth/login` and `/voice_token`, which the log path never reads;
  - on those two routes, only the error *name* (a JSON parse error message can quote the body);
  - any env string value (secrets, API keys, passcodes), the two default passcodes, any bearer value and any token-shaped string, all redacted from every text column.

  A test drives login (good, bad and malformed), voice tokens, telemetry with a JWT, `/tts` with a voice token and a free-text `/turn`, then checks that none of those values or the client IP appears in any row.
- **Teacher-typed text:** only its length (`text_len`) is stored.
- **Rejected model texts are stored** (owner decision), inside `diag.*.rejected`, capped with the diag at 16 KB.
  - **Why:** without them, a fallback cannot be explained after the fact. That is how the parser bug was found.
  - **How:** the texts reach the log through a Symbol key that `JSON.stringify` skips, so API responses are unchanged and still carry the texts only for the debug header.
  - **Flag (consent/IRB):** these are model outputs, not learner input, but the model sees the teacher's typed line, so a rejected reply can quote it.
- **Worker version** comes from the `version_metadata` binding added to `wrangler.toml`.

**Cost.** D1 bills rows written and storage. Workers Paid includes 50 M rows written and 5 GB of storage per month. Please confirm on the account's billing page.
- **Volume:** one extra row write per request.
- **Row size:**
  - a `/turn` row with diag is about 0.5–2 KB;
  - heartbeat and telemetry rows are about 0.3 KB.
- **Scale:** classroom traffic is thousands of rows a day, which is megabytes per month.

## 3. Permanence past D1's cap: R2 archive (built, off) and an off-Cloudflare copy

### `archiveServerLog`
- **Runs:** on a scheduled handler (cron `17 3 1 * *`, monthly).
- **Off unless both:** the `LOG_BUCKET` binding is present, and `LOG_ARCHIVE` is `on` (a secret or var the owner sets).
- **What it writes:** rows in id order, in chunks of 10,000, as gzipped NDJSON at `server_log/<YYYY-MM>/<first_id>-<last_id>.ndjson.gz`.
- **Verification:** each object is **read back, decompressed and checked** (sha256 and row count) before the cursor in `server_log/manifest.json` moves.
- **Not archived in a run:** rows less than one hour old, so in-flight writes are not skipped.
- **Prune:** deletes only rows at or below the verified cursor **and** older than `LOG_KEEP_MONTHS` (default **12**). A failed verification moves nothing and prunes nothing (tested).
- **Bucket name:** `chalk-and-chance-logs` is set once, in `wrangler.toml` `[[r2_buckets]]`. To use another bucket, change that line.

### Off-Cloudflare copy (owner's Box)
`python -I tools/logs/export_logs.py <TARGET_FOLDER> [--d1-snapshot]`
- Reads the bucket and DB names from `wrangler.toml`.
- Downloads every archive object not yet in the folder, verifies it against the manifest before keeping it, and can be re-run.
- `--d1-snapshot` also writes a full `wrangler d1 export` of the live DB, which includes the play telemetry.
- It writes only inside the folder it is given; nothing was written anywhere by this PR. It is tested with a fake wrangler (`tools/logs/test_export_logs.py`).

### R2 cost
Standard storage includes 10 GB-month, then about $0.015 per GB-month. Writes are about 1 object per 10,000 rows. Monthly gzipped NDJSON at classroom scale is a few MB, so this is effectively free.

## 4. Live view: `[observability]` (proposed, not applied)
```toml
[observability]
enabled = true
head_sampling_rate = 1
```
- **Shows:** every invocation and `console.log` in the dashboard and is searchable. Useful for "what is failing right now".
- **Retention:** short (days), so it is not the permanent record.
- **Limits:** Free plan 200k events/day; Paid 20 M/month included, then $0.60/M (published limits; please confirm).

## Running the archive on demand (verification)
The cron runs on the 1st of each month. To run and verify the archive now, against the hosted Worker:

**Setup (once).** Choose a long random token and store it as a secret:
```sh
cd cloudflare && wrangler secret put ADMIN_TOKEN
```
- `/admin/archive` exists only while that secret is set; without it the route answers 404.
- A wrong token gets 403. The route is rate-limited, and the token is redacted from `server_log` rows.
- A separate token is used instead of a signature made with `WORKER_SECRET`, so that the JWT signing key never has to leave Cloudflare or be rotated to run a check.

**1. Dry run.** It writes nothing anywhere:
```sh
curl -s -X POST https://chalk-and-chance-api.jewoong-moon.workers.dev/admin/archive   -H "X-Admin-Token: $ADMIN_TOKEN" -H "Content-Type: application/json" -d '{"mode":"dry"}'
```
It returns:
- `would_write`: key, rows and id range per chunk;
- `cursor`;
- `not_yet_eligible_rows`: rows less than one hour old, which wait for the next run;
- `would_prune_rows`, `prune_cutoff` and `archive_enabled`.

**2. Real run, once.** It never prunes:
```sh
curl -s -X POST https://chalk-and-chance-api.jewoong-moon.workers.dev/admin/archive   -H "X-Admin-Token: $ADMIN_TOKEN" -H "Content-Type: application/json" -d '{"mode":"run"}'
```
- It writes the gzipped NDJSON chunk or chunks and `server_log/manifest.json` to the bucket.
- Each chunk is read back and verified (sha256 and row count) before the cursor moves.
- It deletes nothing from D1, even rows older than `LOG_KEEP_MONTHS`: it only reports `would_prune_rows`.
- The response has `objects`, `cursor_before`, `cursor`, `archived_rows`, `pruned` (always 0), and `checks`:
  - `objects_written`, `read_back_verified`, `manifest_cursor_moved`, `archived_rows_still_in_d1` and `nothing_pruned`;
  - `pass` is true only if all five hold.
- It is still a no-op (`{"skipped":"off"}`) unless `LOG_ARCHIVE` is `on`.
- A second run within the hour shows `manifest_cursor_moved: false`, because only the first run's own log rows are new.

**3. Independent read-only check.**
```sh
python -I tools/logs/verify_archive.py
```
It downloads the manifest and every chunk and checks:
- sha256, row count, id order and range, and that chunks do not overlap;
- that the cursor is the last chunk's last id;
- that each archived row is identical to its D1 row and that no D1 row in the range was skipped;
- that nothing was pruned.

It prints PASS or FAIL per check and `RESULT: PASS` at the end, with exit code 0. It uses only `wrangler r2 object get --pipe` and D1 `SELECT`s.

## Owner steps (in order)
1. Merge. Apply the migration: `wrangler d1 execute chalk_db --remote --file cloudflare/migrations/0001_server_log.sql`.
2. `wrangler deploy`. This binds `LOG_BUCKET` and `CF_VERSION_METADATA` and registers the monthly cron, which does nothing while `LOG_ARCHIVE` is unset.
   - This PR adds no `[vars]` block on purpose: deploying a `[vars]` block can remove plain-text vars that were set in the dashboard.
3. When ready, turn the archive on: `wrangler secret put LOG_ARCHIVE` with value `on`. Optionally set `LOG_KEEP_MONTHS`.
4. Periodically run `export_logs.py <Box folder> --d1-snapshot`.

## Decisions that need the owner
1. **Workers plan.** On Free, the 500 MB D1 cap is near: 183 MB used.
2. **`LOG_KEEP_MONTHS`.** The default is 12 months in D1 before archived rows are pruned. A setting of `0` would keep D1 small; a very large number never prunes.
3. **Consent/IRB.** Rejected model texts can quote teacher-typed text. Separately, teacher-typed text is already stored in `telemetry_*_events.event.move.text`; that is not new, but it is worth confirming it is covered.
4. ~~Linking `/turn` rows to play sessions~~: done in the follow-up PR (client sends `anon_id` + the real `session_id`).
5. **`[observability]`.** Turn it on as the live view, yes or no.
6. ~~Raw IPs in `rate_limits` keys~~: replaced with a keyed hash in the follow-up PR. Rows written before that deploy expire within an hour.
