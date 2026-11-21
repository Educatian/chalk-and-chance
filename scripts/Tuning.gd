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

# --- B4 least-intrusive ladder (Simonsen et al., 2008) for behaviour interrupt cards ------
## Step names, lowest first. Options carry "tier" (1-4) and "works" for that situation.
const LADDER_STEPS := ["Proximity", "Nonverbal", "Brief word", "Public correction"]
## Composure bonus for choosing the lowest step that works on that card.
const LADDER_BONUS_COMPOSURE := 3.0
## The period clock keeps running this long while an interrupt card is open.
const INTERRUPT_CLOCK_SECONDS := 2.0

# --- B2 professional noticing (Jacobs, Lamb & Philipp, 2010) ----------------------------
## The chips, in hotkey order (1-4).
const NOTICE_CHIPS := ["confused", "gets_it", "withdrawn", "distracted"]
const NOTICE_LABELS := {"confused": "Confused", "gets_it": "Gets it", "withdrawn": "Withdrawn", "distracted": "Distracted"}
## Shown emotion -> chips that read it correctly (first = the category that, when it
## changes, prompts a new noticing step).
const NOTICE_TRUTH := {
	"confused": ["confused"], "thinking": ["confused", "gets_it"],
	"curious": ["gets_it"], "engaged": ["gets_it"], "excited": ["gets_it"], "proud": ["gets_it"], "warming": ["gets_it"],
	"shy": ["withdrawn"], "withdrawn": ["withdrawn"], "anxious": ["withdrawn", "confused"],
	"frustrated": ["withdrawn", "distracted"], "neutral": ["distracted", "confused"],
}
## At most this many noticing prompts per encounter (uncapped probe: mean 3.5, max 7).
const NOTICE_MAX_PROMPTS := 3
## A correct read adds this to the understanding credit of the next move that lands.
const NOTICE_CREDIT_BONUS := 0.03
