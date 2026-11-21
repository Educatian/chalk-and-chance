# Test traffic that reached the hosted API (2026-11-20/21)

This document lets the owner find and remove my test traffic from the hosted Worker (`https://chalk-and-chance-api.jewoong-moon.workers.dev`). I have not touched the Worker or its data.

## What happened

- **Browser screenshot runs.** Off-screen screenshot runs of local web exports used the shipped `data/auth_config.json`, which points web builds at the hosted Worker. My local URLs did not add `?public_demo=1`, so those runs could:
  - send live student turns to `POST /turn` (Gemini);
  - post anonymous telemetry to `POST /telemetry_anon`.

  Voice (TTS) stayed gated. No signed-in accounts were used.
- **AnonTelemetryTest.** This existing dev suite deliberately uploads to the live Worker on every run, under a `ci_anon_*` id. I ran it as part of every full suite run.

## Time windows

Times are workspace local (US Central, UTC−6) and UTC. They are reconstructed from screenshot and log file timestamps in my scratchpad.

| local (CST) | UTC | runs (scratch folders) | could reach |
|---|---|---|---|
| 2026-11-20 23:38 – 11-21 01:01 | 11-21 05:38 – 07:01 | earlier session: root shots, shots_before, shots_c2, shots_c3, shots_aspect (1560x720, 1024x768, 390x844, 1280x720), after | /telemetry_anon; /turn from any encounter turns played |
| 11-21 07:15 – 08:28 | 13:15 – 14:28 | scale, mod/kr, mod/us, screens (+lecture, gym), enc3, b4 (all missions, end, win, import, preview) | /telemetry_anon; /turn (b4/win, enc3) |
| 11-21 08:41 – 09:41 | 14:41 – 15:41 | a1 (res, hub, end, room), b1 (held, cut), b2 (e, n, l), lad (a, h, e, b, c) | /telemetry_anon; /turn (a1/res, b1, b2/n, lad/e) |
| 11-21 11:20 – 11:27 | 17:20 – 17:27 | br (t, s, r, l2, r2, t3) | /telemetry_anon; /turn (br/r, br/r2) |
| 11-21 12:07 | 18:07 | kr (t, c, e, r, d): the Korean screenshots | /telemetry_anon; /turn (kr/e, kr/r) |

- **Fix point.** Commit `86b6b10` (11-21 about 12:20 local / 18:20 UTC; cherry-picked to #4, #5 and #6): any `dev_*` URL now forces offline students, no voice and no uploads. A later commit adds NetGuard, so debug builds refuse the hosted origin unless opted in. No web run after these commits can reach the API.
- **Missing runs.** Some runs inside these windows wrote to folders I later deleted or overwrote, so treat each window as a whole. Runs before 2026-11-20 23:38 local (earlier sessions in other scratch folders) cannot be reconstructed from here.

## How to recognise the traffic

**Every browser session's first telemetry event**, `session_start`, carries:
- `"engine": "4.7.2.stable.official.ed1daf0bf"`. My exports used the local Godot 4.7.2; the project targets 4.6.
- `"client.url"`:
  - `http://127.0.0.1:8762/index.html...` (release export) or `http://127.0.0.1:8763/index.html...` (debug export);
  - most debug URLs have `dev_room=`, `dev_win=`, `dev_moves=`, `dev_gap=`, `dev_end=1`, `dev_interrupt=`, `dev_screen=`, `dev_lang=ko`, `dev_korean=1`;
  - runs against the public site used `https://educatian.github.io/chalk-and-chance-play/?public_demo=1` (stub students, telemetry possible).
- `"client.ua"` containing `HeadlessChrome`.
- `"client.referrer": ""`, `"client.lang": "en-US"`, `"client.tz": "America/Chicago"`.
- `"client.screen"`: mostly `1280x720`, sometimes `1560x720`, `1024x768`, `390x844`.

**Other identifiers**
- **`anon_id`:** `a_<unix seconds>_<microseconds>`, a new one per run (each run used a fresh browser profile), with `<unix seconds>` inside the windows above.
- **`session_id`:** `sess_<unix>_<n>`.
- **HTTP:** Origin/Referer `http://127.0.0.1:8762` or `:8763`; User-Agent HeadlessChrome.
- **Missions and students touched:**
  - missions: discussion_fractions (dev_win default), lecture_fractions, group_work_fractions, independent_fractions, gym_capstone, culturally_responsive_intro, reading_main_idea, science_force_motion, custom_comparing_decimals;
  - `/turn` personas: jordan_skeptic, priya_quiet, meilin_anxious, noah_g5_fractions.

**AnonTelemetryTest rows**
- anon_id `ci_anon_<n>`, `session_start.engine = "anon_test"`, `client.url = "test://anon"`.
- Each run posted 4 events: session_start, player movement, a turn and a heartbeat.
- Recovered ids:

| local time | UTC | anon_id |
|---|---|---|
| 11-21 00:24 | 06:24 | ci_anon_251321 |
| 00:34 | 06:34 | ci_anon_356751 |
| 00:46 | 06:46 | ci_anon_250911 |
| 00:55 | 06:55 | ci_anon_349608 |
| 01:02 | 07:02 | ci_anon_279753 |
| 07:15 | 13:15 | ci_anon_273112 |
| 08:03 | 14:03 | ci_anon_304139 |
| 08:07 | 14:07 | ci_anon_303569 |
| 08:10 | 14:10 | ci_anon_308096 |
| 08:16 | 14:16 | ci_anon_303249 |
| 08:27 | 14:27 | ci_anon_301469 |
| 08:38 | 14:38 | ci_anon_288503 |
| 08:44 | 14:44 | ci_anon_316472 |
| 08:52 | 14:52 | ci_anon_314193 |
| 09:03 | 15:03 | ci_anon_458624 |
| 09:08 | 15:08 | ci_anon_324031 |
| 09:10 | 15:10 | ci_anon_354898 |
| 09:12 | 15:12 | ci_anon_287331 |
| 09:14 | 15:14 | ci_anon_286016 |
| 09:19 | 15:19 | ci_anon_278347 |
| 09:21 | 15:21 | ci_anon_337292 |
| 09:24 | 15:24 | ci_anon_274692 |
| 09:25 | 15:25 | ci_anon_268721 |
| 09:28 | 15:28 | ci_anon_283860 |
| 09:35 | 15:35 | ci_anon_268965 |
| 09:37 | 15:37 | ci_anon_448308 |
| 11:08 | 17:08 | ci_anon_340681 |
| 11:16 | 17:16 | ci_anon_277515 |
| 11:22 | 17:22 | ci_anon_400981 |
| 11:26 | 17:26 | ci_anon_312001 |
| 11:28 | 17:28 | ci_anon_370932 |
| 11:30 | 17:30 | ci_anon_323996 |
| 11:32 | 17:32 | ci_anon_353228 |
| 11:35 | 17:35 | ci_anon_541324, ci_anon_472400, ci_anon_548935, ci_anon_501885 (PR #3–#6 re-runs) |
| 11:39 | 17:39 | ci_anon_461293 |
| 11:41 | 17:41 | ci_anon_436922 |
| 11:45 | 17:45 | ci_anon_315190 |
| 12:03 | 18:03 | ci_anon_338311 |
| 12:05 | 18:05 | ci_anon_415199 |

That is 42 ids. More ci_anon runs happened whose logs were overwritten (folders reused), plus 1–3 runs by the copy-pass agent between about 11:15 and 11:31 local. Their ids are not recoverable; they all share `engine = "anon_test"`.

## Request shapes (for a filter)

**`POST /turn`**
- Headers: `Content-Type: application/json` only.
- Body:
```json
{"session_id": "m1", "scenario_id": "discussion_fractions", "scenario_context": {...},
 "target_behavior": "elicit_student_thinking", "active_persona_id": "noah_g5_fractions",
 "runtime_state": {"understanding": 0.15, "engagement": 0.4, "trust_in_teacher": 0.5,
   "misconception_resolved": false, "turns_elapsed": 1},
 "teacher_move": {"input_mode": "menu", "menu_tag": "elicit", "wait_time_ms": 3000, "raw_wait_time_ms": 3120},
 "win_moves": [...], "dialogue_tail": [...], "move_history": [...],
 "model_profile": "openrouter_gemini"}
```

**`POST /telemetry_anon`**
- Sent by HTTPRequest, or by `fetch(keepalive)` on page unload.
- Body:
```json
{"anon_id": "a_1763700000_123456",
 "events": [{"event": "session_start", "engine": "4.7.2.stable.official.ed1daf0bf",
             "client": {"platform": "Web", "locale": "en_US", "url": "http://127.0.0.1:8763/index.html?dev_win=...",
                        "referrer": "", "ua": "Mozilla/5.0 ... HeadlessChrome/...", "lang": "en-US",
                        "screen": "1280x720", "tz": "America/Chicago"},
             "session_id": "sess_...", "t_ms": 1234, "unix": 1763700000.0, "anon_id": "a_..."},
            ...]}
```

A sufficient filter: rows where `anon_id LIKE 'ci_anon_%'`, or whose session has a `session_start` with `client.ua LIKE '%HeadlessChrome%'` or `client.url LIKE 'http://127.0.0.1:876%'`. For `/turn` there is no stored marker on my side; Worker logs from those windows with Origin `http://127.0.0.1:876x` would be the way to find them.

## What I cannot reconstruct

- The `a_*` anon_ids of browser runs. Each headless profile was deleted after its run.
- The exact number of `/turn` calls. My estimate is 40–60, from about 15 encounter runs with an opener plus 1–4 moves each.
- Runs whose screenshot folders I deleted or overwrote inside the windows above.
- Anything before 2026-11-20 23:38 local.
- The copy-pass agent's ci_anon ids.

## Guards now in place

- **NetGuard** (`scripts/NetGuard.gd`): debug builds refuse every non-local host unless the run opts in. The opt-in is `-- --allow-hosted` on the command line, `CHALK_ALLOW_HOSTED=1` in the environment, or `?allow_hosted=1` on web. It covers Auth (including the keepalive beacon), telemetry, `/turn`, group/lecture/gym turns, voice and lesson import; each falls back to its offline path. Release builds are unchanged.
- **AnonTelemetryTest** skips unless opted in.
- **Debug web hooks**: any `dev_*` URL forces offline students, no voice and no uploads.
- **`tools/qa/web_run.py`**: the committed off-screen runner. It refuses non-local start pages, aborts every non-local request at the browser, and exits 3 if any was attempted.
- **Verified** on 2026-11-21 with the same flow (title → Play → hub, 45 s idle):
  - The debug export attempted 0 non-local requests.
  - The release export attempted 2 `POST …workers.dev/telemetry_anon`, blocked at the browser, so release behaviour is unchanged and nothing left the machine.
  - FeelCheck covers the NetGuard decision for debug, opt-in and release.
