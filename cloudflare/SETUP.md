# Per-learner login + ECD upload — all-Cloudflare setup (Worker + D1)

One stack does everything the Supabase plan would: named-account login (class code +
name + password), JWT, and per-learner telemetry + competency upload. ~5 minutes.

## One-time provisioning (you run these — wrangler is gated, use `!`)

```bash
cd cloudflare

# 1. create the D1 database, then paste the printed database_id into wrangler.toml
wrangler d1 create chalk_db

# 2. create the tables (remote)
wrangler d1 execute chalk_db --remote --file schema.sql

# 3. create a class + (optional) seed
wrangler d1 execute chalk_db --remote --file seed.sql

# 4. set the JWT signing secret (any long random string)
wrangler secret put WORKER_SECRET

# 5. deploy the API
wrangler deploy
# -> prints  https://chalk-and-chance-api.<you>.workers.dev   (this is API_BASE)
```

Then put that URL in the game: edit `data/auth_config.json` → `"api_base"`.

## What the learner sees (easy, guided — no email/signup)

1. Game opens on a **Login** screen.
2. Enter the **class code** (e.g. `UA-CAT531-SUMMER26`), **your name**, and a **password**.
3. First time in an open class = auto-enrolled (your password is set). Next time = sign in.
4. Play. **Every lesson's telemetry + competency uploads automatically under your name** —
   no upload button, works across devices/browsers.

## Instructor (cohort view)

After logging in once, promote yourself (see `seed.sql` comment), then your JWT can read the
whole class's `telemetry_events` + `competency`. Query with `wrangler d1 execute ... --command`
or build a small dashboard later.

## Notes

- The game web build is on GitHub Pages (36 MB wasm > Cloudflare Pages 25 MB limit); that is
  fine — the game just calls this Worker API cross-origin (CORS is open in worker.js).
- Passwords are PBKDF2-SHA256 hashed in the Worker; the JWT is HMAC-signed with WORKER_SECRET.
- Offline / not-signed-in still works: telemetry falls back to local `user://telemetry`.

## Korean students (locale) — owner deploys

The game sends `"locale": "ko"` (or `"en"`) in every `/turn`, `/group_turn` and `/lecture_turn`
body. In this repo the Worker already reads it (`cloudflare/locale.js`):
- Korean persona overlays (`data/i18n/ko/persona_library`) are merged over the English persona;
- Korean rules are appended to the student, coach and group prompts (`tools/student_prompt_ko.txt`,
  `tools/coach_prompt_ko.txt`): child voice, 존댓말 해요체 to the teacher, no translationese;
- Korean replies with English words or a leaked answer are rejected and retried; the fallback
  lines and coach tips are Korean.
A missing `locale` (older clients) keeps today's English behaviour.

**Until this is deployed, the hosted students keep answering in English.** To ship it:
```bash
python cloudflare/build_gamedata.py   # already run in the PR; re-run after editing personas/prompts
node --test cloudflare/test/locale.test.mjs cloudflare/test/replay.test.mjs   # local stub + replay of real lines, no network
cd cloudflare && wrangler deploy
```
No secrets, D1 schema or bindings change. The web game must also be rebuilt from this branch so
it sends `locale` (the Worker change is harmless without it; the client change is harmless
without the Worker change).
