extends RefCounted
## Every timing window, bonus and penalty added by the mechanics-alignment (B) rules, in
## one place, so a playtest can tune them without hunting through scenes.

# --- B1 wait time (Rowe): WT-I think time after a question, WT-II after the answer ------
## Moves after which the student thinks before answering (WT-I). The think time itself is
## GameState.wait_threshold_ms() (3 s, shortened by the wait-mastery upgrade/profile).
const THINK_TAGS := ["elicit", "extend", "wait"]
## WT-II: pause after the student's answer before the next move counts as waited.
const WT2_WINDOW_MS := 1500
## Idle past this after the answer costs a little engagement, once per turn.
const WT_LONG_MS := 5000
const WT_LONG_ENGAGEMENT := -2.0
## Speaking into the think time: the student drops the thought.
const CUT_DELTAS := {"understanding": 0.0, "trust": -0.03, "engagement": -0.04, "order": 0.0, "composure": 0.0}
const CUT_LINE := "...oh. Never mind."

# --- B3 feedback kinds (Hattie & Timperley): specific vs generic praise -----------------
## Praise is specific only when there is something nameable: the last move landed, or
## praise fits the student's path now. Generic praise: this much trust, no understanding, no path progress, and
## it is not evidence of behaviour-specific praise.
const PRAISE_GENERIC_DELTAS := {"understanding": 0.0, "trust": 0.02, "engagement": 0.0, "order": 0.0, "composure": 0.0}

# --- B6 equity of voice: "every student contributes" means their thinking was heard -----
## A student counts toward engaged_min only once one of these landed with them (1:1).
const VOICE_TAGS := ["elicit", "revoice"]
## Group check-in: a productive one of these counts every member of that pod as heard.
const GROUP_VOICE_TAGS := ["probe", "redistribute"]

# --- B8 deliberate practice: the debrief's next target becomes the retry's objective 1 ----
## XP for meeting the carried-forward retry focus on the next attempt.
const RETRY_XP_BONUS := 40
