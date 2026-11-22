# Live check of the play site after play PR #1 (build cb5c3f6, merge 1eaf169)

On 2026-11-22 there was one load per language of https://educatian.github.io/chalk-and-chance-play/?public_demo=1 at 1280x720.
- **Runner:** headless Chromium via `tools/qa/web_run.py` with `CC_LIVE_HOSTS=educatian.github.io,chalk-and-chance-api.jewoong-moon.workers.dev`. Every other host was aborted, and `NETWORK blocked=0` in both runs.
- **Students:** `public_demo=1` keeps them as stubs, so no `/turn` was sent and no LLM was called.

| load | what it shows | served `index.pck` | telemetry posted (UTC) | marks to exclude |
|---|---|---|---|---|
| en | new title and logo → Play → English hub | 200, 13,081,732 bytes (the new build; the old was 13,081,220) | 11:19:22 `POST /telemetry_anon` (session_start, 2 input_key, ui_button_pressed) | anon_id `a_1795346350_509200`, session `sess_1795346350_9200` |
| ko | English title → language button → Korean title → 시작 → Korean hub | 200, 13,081,732 bytes | 11:20:03 (session_start, mouse, keys, 2 ui_button_pressed) and 11:20:27 (heartbeat) | anon_id `a_1795346397_510900`, session `sess_1795346397_10900` |

Other files served were index.html 5,734, index.js 279,815 and index.wasm 39,514,754 bytes. There were no 4xx/5xx and no console errors. The screens are `{en,ko}_*.png` and `sheet.png`, and every request with its status, size and the telemetry body is in `{en,ko}_live_requests.json`.
