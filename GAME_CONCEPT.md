# CHALK & CHANCE
## Game Concept Document (Concept-Stage GDD)
### A Pokemon-Style 2D Arcade Teacher-Simulation Game in Godot 4

Status: concept stage. This document is the single source of truth for terminology, mechanics, and the literature warrant behind each design decision. Every mechanic is anchored to a verified or flagged citation. Where the source synthesis flagged a citation as unverified or future-dated, it is marked `[unverified]` and must not be used in any publication-facing claim without confirmation against the live OpenAlex/Crossref API.

---

## 0. Canonical Terminology (read this first)

The design fragments used several working titles and overlapping names. This section freezes one consistent vocabulary used throughout the rest of the document. All later sections defer to this table.

| Concept | Canonical term | Rejected alternatives now retired |
|---|---|---|
| Game title | **Chalk & Chance** | "Chalk & Chaos", "TeachQuest", "TeacherSim", "Maple Ridge" |
| School setting | **Maple Ridge School**, on the continent **Praxis** | (kept both; school is the building, Praxis is the world map) |
| The four meters | **Engagement, Order, Rapport, Composure** | "Trust" (folded into Rapport), "Understanding" (now a per-NPC runtime field, not a class meter) |
| Per-student internal value | **Understanding** (NPC runtime state, not a HUD class meter) | (was conflated with class Engagement in some fragments) |
| Teaching moves (the "fight menu") | **Elicit, Extend, Revoice, Tell/Model, Praise, Redirect, Wait** | "Explain/Question/Encourage/Scaffold" naming from the art fragment is retired in favor of the literature-tagged set |
| Competency unit | **Badge** (one decomposed high-leverage practice per badge) | "level", "XP" |
| World subdivision | **Region** (a Region groups the missions that build toward one Badge) | "Zone" (now reserved for art/palette only) |
| Final integration content | **The Capstone Coliseum** (houses the integration bosses) | "Elite Four", "Integration Room" |
| Regional boss mission | **Gym** | "boss approximation" |
| The mentor/coach | **Coach Vee (Dr. Vera Okonkwo)** | "Professor Oak role", "Staff-Room Coach" |

Abbreviations: HLP = high-leverage practice (TeachingWorks). BSP = behavior-specific praise. WT-I / WT-II = Wait Time I (after a question) / Wait Time II (after a student answer). OTR = opportunities to respond.

---

## 1. Elevator Pitch and Design Pillars

### 1.1 Elevator Pitch

Chalk & Chance is a Pokemon-style 2D top-down game where you play a first-year teacher walking the halls of Maple Ridge School; every classroom door is one named, observable teaching skill, and every "battle" is a read-act-observe dialogue against LLM-driven student agents who hold frozen misconceptions and will not simply agree with you. You win a classroom moment not by lecturing the right answer but by surfacing a student's own reasoning through eliciting, extending, revoicing, well-timed silence, and feedback that names the next step. You advance by mastering one decomposed teaching behavior at a time (gym badges), with a coach who gives typed, specific, fading, next-step feedback every round, because the evidence says coaching and feedback, not graphical fidelity, are what make simulated practice transfer to real classrooms.

### 1.2 Design Pillars

1. **Decomposition before integration.** One classroom door equals exactly one high-leverage practice. Holistic "good teaching" is never scored; only named sub-skills are (Forzani 2014; Grossman et al. 2009).
2. **Score the player, not the student.** Every teacher utterance is tagged (elicit / extend / take-over / revoice / acknowledge / praise / redirect / wait-time). Progress gates on accumulating responsive moves, since novices systematically under-use revoicing and eliciting (Cultivating Responsive Teaching, JMTE 2026; LAK 2025).
3. **Feedback over fidelity.** The active ingredient is the immediate, specific, next-step coach feedback and the move-tagged debrief, not the art. This is what the coaching-augmented mixed-reality RCTs and meta-analysis credit (Bondie et al. 2023; MR meta-analysis g approximately 0.56).
4. **Deliberate practice loop.** Enact, immediate coached feedback, structured reflection, retry; mastery-gated, with spaced re-encounter of earlier skills (Ericsson et al. 1993 `[unverified ID]`; McGaghie et al. 2011 mastery learning).
5. **Validity-first simulated students.** Frozen knowledge/misconception state, anti-sycophancy guardrails, injected realism defects, and bias-audited personas, engineered directly against the four documented LLM-student failure modes.

---

## 2. Evidence Base: Target Behaviors and Their Warrants

Each row is a teacher behavior the game instruments as a clean telemetry signal, with the strongest available citation. DOIs/IDs are reproduced from the source synthesis; verification status is explicit.

| Target behavior (in-game) | What is measured | Primary warrant | Verification |
|---|---|---|---|
| Wait Time I and II | ms before naming a student / before reacting to an answer; reward 3 to 5s | Rowe 1986, DOI 10.1177/002248718603700110, OpenAlex W100240282 | Verified |
| Managed equitable participation (cold/warm call) | pose-pause-name sequence; call distribution across NPCs | Dallimore, Hertenstein & Platt 2012, DOI 10.1177/1052562912446067, W2055221540; 2006, W2016981678 | Verified |
| Warm-call scaffolding (advance notice, opt-out) | affect cost avoided while raising participation | Metzger & Via 2022, DOI 10.1525/abt.2022.84.6.342, W4288683840 | Verified |
| Behavior-specific praise; praise-to-reprimand ratio | rate of BSP vs reprimand; named vs generic | Reinke, Lewis-Palmer & Merrell 2008, DOI 10.1080/02796015.2008.12087879, W4297791801; Briere et al. 2013, DOI 10.1177/1098300713497098, W2161429155 | Verified |
| Least-to-most-intrusive redirect | intrusiveness tier chosen; de-escalation vs escalation | Simonsen, Fairbanks, Briesch, Myers & Sugai 2008, DOI 10.1353/etc.0.0007, W2123255948 | Verified |
| Professional noticing (attend, interpret, decide) | accuracy of attend/interpret stages | Jacobs, Lamb & Philipp 2010, DOI 10.5951/jresematheduc.41.2.0169, W23678119 | Verified |
| Eliciting / extending vs taking over student thinking | elicit:take-over ratio; revoice count | Cultivating Responsive Teaching, JMTE 2026, DOI 10.1007/s10857-026-09751-4; LAK 2025, DOI 10.1145/3706468.3706570 | DOIs as supplied `[unverified: post-cutoff dating]` |
| Formative feedback by TYPE (task/process/self-reg, not person-praise) | feedback-type tag per utterance | Hattie & Timperley 2007, DOI 10.3102/003465430298487; Wisniewski, Zierer & Hattie 2020, DOI 10.3389/fpsyg.2019.03087, W3002947507 | Wisniewski 2020 verified; Hattie 2007 `[unverified ID]` |
| Leading a group discussion (revoice, press, connect) | connect-across-speakers tags | TeachingWorks HLP; Grossman et al. 2009 decomposition | Grossman ID `[unverified]` |
| Coordinating/adjusting instruction mid-lesson | replan-after-cue events | TeachingWorks HLP #6 | Live-site numbering `[unverified]` |
| Diagnosing common error patterns | misconception-named-correctly flag | TeachingWorks HLP #4; Jacobs 2010 | HLP numbering `[unverified]` |
| Building relationships / learning student resources | connect-to-resources tag | TeachingWorks HLP #12; McLeskey et al. 2019, DOI 10.1177/0741932518773477, W2981777059 | McLeskey verified; HLP numbering `[unverified]` |
| Maintaining composure / reflection-in-action | recovery-after-error events | Eraut 1995, DOI 10.1080/1354060950010102, W2010291646; Schon 1983/1987 (books) | Eraut verified; Schon has no single work ID |
| Effective scaffolding (contingency, fading, transfer) | hint level vs performance | van de Pol, Volman & Beishuizen 2010, DOI 10.1007/s10648-010-9127-6, W2156300785 | Verified |
| Cognitive-load-managed sequencing (worked-example-to-problem fading) | representation-first then fade | Sweller, van Merrienboer & Paas 2019, DOI 10.1007/s10648-019-09465-5, W2913144876 | Verified |
| Deliberate practice at the edge of ability | adaptive difficulty | Ericsson, Krampe & Tesch-Romer 1993, DOI 10.1037/0033-295X.100.3.363 | `[unverified ID]` |
| Mastery learning (advance only at competency bar) | mastery gate | McGaghie et al. 2011, DOI 10.1097/ACM.0b013e318217e119; Barsuk et al. 2012, W2128693346 | Verified |
| Coached differentiated practice transfers | (design rationale) | Bondie, Zusho, Wiseman, Dede & Rich 2023, DOI 10.1037/tmb0000098, W4319863249 | Verified |
| Habit-plateau countermeasure (deliberate practice over experience) | spaced re-encounter | Hobbiss, Sims & Allen 2020; Sims & Fletcher-Wood 2020, DOI 10.1080/09243453.2020.1772841 | `[unverified IDs]` |

**LLM-student validity findings (drive Section 7):**

| Failure mode designed against | Warrant | Verification |
|---|---|---|
| Sycophancy / answer-flip (up to 15 to 30 pp) | "Check My Work?" 2025, arXiv:2506.10297 | `[unverified: arXiv preprint]` |
| Competence paradox (fluent model masks unreal errors) | Towards Valid Student Simulation 2026, arXiv:2601.05473 | `[unverified: future-dated arXiv]` |
| Four realism defects (language complexity, no emotion, unnatural attentiveness, logical inconsistency) | Martynova et al. 2025 (BEA), DOI 10.18653/v1/2025.bea-1.8 | Verified venue |
| Demographic/clinical (ADHD-skew) bias | LLMs are Biased Teachers 2024, arXiv:2410.14012 | `[unverified: arXiv]` |
| Structure beats model size | Simulating Students review 2025, arXiv:2511.06078 | `[unverified: future-dated arXiv]` |
| Text-chat lowers stress, supports iteration | Markel, Opferman, Landay & Piech 2023 (GPTeach), DOI 10.1145/3573051.3593393 | Verified |
| Multi-agent populated classroom feasible | SimClass (NAACL 2025), DOI 10.18653/v1/2025.naacl-long.520, W4411119608; MathVC arXiv:2404.06711 | SimClass verified; MathVC `[unverified: arXiv]` |
| Mixed-reality lineage / transfer | Dieker et al. 2023, DOI 10.3390/educsci13111070, W4387904293; Ersozlu et al. 2021, DOI 10.1177/21582440211032155 | Verified |

**Verification mandate:** before any publication-facing use, run the `refcheck` skill against the full list. Confirmed-good anchors for effectiveness claims are the coaching-augmented MR RCTs, the MR meta-analysis (g approximately 0.56), Sweller 2019, van de Pol 2010, Wisniewski/Hattie 2020, Bondie 2023, Barsuk 2012, McLeskey 2019, Rowe 1986, Simonsen 2008, Reinke 2008, Dallimore 2012, Metzger & Via 2022, Jacobs 2010, Eraut 1995.

---

## 3. Core Game Loop and Mechanics

### 3.1 The Overworld (Pokemon Layer)

A top-down, tile-based school walked with arrow keys. The map is the progression spine. The split into Prep Desk, Classroom, and Staff Room operationalizes the prepare-enact-reflect cycle of practice-based methods courses (Grossman et al. 2009).

| Location | Function | Mechanic it hosts |
|---|---|---|
| **Classroom doors** | Trigger encounters | Each door = one named HLP mission |
| **Hallway** | Travel + random incident micro-encounters (off-task student, hallway conflict) | Short classroom-management reps |
| **Staff Room** | Coach Vee hub: debrief, badge/skill tree, replay expert exemplars | Reflection-on-action + representation viewing |
| **Prep Desk (your room)** | Pre-mission planning: pick objective, read roster, set a goal | "Prepare" stage of the cycle |

**Design rule:** one classroom door equals ONE decomposed practice, never "teach a good lesson" holistically (Forzani 2014; Grossman et al. 2009).

### 3.2 The Encounter Screen (Battle Layer)

The player is the live teacher addressing **4 to 5 visibly varied student avatars** (the "enemy party"). Visible variation in engagement, mood, and neurodivergence, plus reward for differentiated responses, follows the avatar-diversity finding (TeachLivE/Mursion lineage; McLeskey et al. 2019).

```
+--------------------------------------------------+
|  [Student sprites: 4-5, each with affect icon]   |  <- the "party"
|                                                  |
|  CLASS METERS                                    |
|  ENGAGEMENT ######....   ORDER #######...        |
|  RAPPORT    #####.....                            |
|                                                  |
|  +------------- WAIT-TIME RING -------------+     |  <- timing mechanic
|                                                  |
|  YOUR MOVES (Pokemon-style):                     |
|  [ Elicit ] [ Extend ] [ Revoice ] [ Tell/Model ]|
|  [ Praise ] [ Redirect ] [ Wait ]                |
|                                                  |
|  COMPOSURE ########..   (your HP)                |
|                                                  |
|  EQUITY TRACKER  [calls|praise|redirects/NPC]    |  <- side panel
+--------------------------------------------------+
```

### 3.3 The Four Meters

Three are **class state** (the "enemy" side); the fourth is **your state** (your HP). Note: per-student `Understanding` is an internal NPC runtime value (Section 7), surfaced indirectly through the NPC's own words and the coach tip, not as a class HUD bar.

| Meter | Tracks | Rises when | Falls when | Anchor |
|---|---|---|---|---|
| **Engagement** (class) | Cognitive participation | High OTR, eliciting, good wait time, equitable cold calls | Over-telling, one student monopolizes, purposeless dead air | Simonsen 2008 |
| **Order** (class) | Behavioral climate | BSP, least-intrusive redirects, clear routines | Escalation, ignored off-task, reprimand-heavy | Simonsen 2008 |
| **Rapport** (class) | Relational safety | Revoicing, acknowledging contributions, warm-call scaffolds, using student resources | Cold-calling the anxious student unwarned, person-blame | TeachingWorks HLP #12; Metzger & Via 2022 |
| **Composure** (you = HP) | Your regulation under pressure | Recovering after an error, staying on protocol | Repeated escalation, panic-telling, backfiring moves | Eraut 1995; Teacher Moments lineage |

**Composure is HP, not a lose-at-zero bar.** Hitting zero triggers a **forced de-escalation micro-lesson plus a retry of the segment**, not a game-over, implementing error-as-data (Ericsson et al. 1993 `[unverified ID]`).

### 3.4 Turn Structure: the Read-Act-Observe Cycle

Each turn is a three-beat cycle lifted from the simSchool decision loop (read state, pick move under pressure, see change, running score).

**Beat 1, READ (Professional Noticing).** A student NPC says or does something. The player must tag it through a three-step noticing widget before any move unlocks (Jacobs et al. 2010):
1. **Attend** ("What did you see?") pick the salient cue.
2. **Interpret** ("What does it mean?") diagnose the misconception or affect.
3. **Decide** ("What next?") this gates which moves are highlighted.
The NPC's next line branches on the player's interpretation accuracy.

**Beat 2, ACT (Choose a Move plus Wait-Time Ring).** Two timing mechanics fire:
- **Wait-Time Ring (signature mechanic).** After posing a question, a ring fills for ~3s. Naming a student before the ring completes = penalty (Engagement drop, "you rushed"); holding 3 to 5s = bonus. A second ring (WT-II) appears after a student answer, before the teacher reacts. A literal timer implementation of Rowe 1986.
- **Move types and scored effects:**

| Move | Effect | Anchor |
|---|---|---|
| **Elicit** | Open/probing question; raises Engagement, surfaces NPC reasoning | JMTE 2026 elicit vs take-over |
| **Extend** | "Why? How do you know?"; presses reasoning without solving it | JMTE 2026 |
| **Revoice** | Restates the student's contribution; large Rapport gain; the move PSTs skip | LAK 2025 |
| **Tell/Model** | Worked example, think-aloud; necessary but over-use drops Engagement | Sweller 2019 guidance-fading |
| **Praise** | Must name the specific behavior (BSP); raises Order + Rapport | Reinke 2008; Briere 2013 |
| **Redirect** | Opens a least-to-most-intrusive sub-menu (proximity, nonverbal, brief verbal, error correction) | Simonsen 2008; McLeskey 2019 |
| **Wait** | Deliberate silence; can raise Engagement at the right moment | Rowe 1986 |

**Beat 3, OBSERVE (Branching NPC Response plus Live Rubric Tag).** The NPC responds; meters update visibly. Every player utterance is live-tagged by the rubric engine as `elicit / extend / take-over / revoice / acknowledge / praise(specific|generic) / redirect(tier) / wait-time-met`. Scoring the player's moves and gating progress on elicit+extend over take-over is the core scoring design (Barno et al. 2025; JMTE 2026).

### 3.5 Equity and Participation Tracker (a First-Class Score)

A persistent side panel shows who has been called on, praised, and redirected, as a distribution across the NPCs.
- **Cold Call:** pose to whole class, ring fills, THEN name a student. Correct pose-pause-name lifts Engagement (Dallimore 2012).
- **Warm-Call scaffold:** advance notice or opt-out to a high-anxiety NPC before naming prevents a Rapport hit (Metzger & Via 2022).
- **Equity penalty:** skewing attention to the confident NPC and ignoring the disengaged one drops the equity band. Distribution of teacher attention is a first-class score.

### 3.6 Scoring Rubric

Score is a **breakdown by behavior type, never a single holistic grade.**

| Dimension | Measured signal | Anchor |
|---|---|---|
| Wait-time fidelity | % of questions held >= 3s (WT-I and WT-II) | Rowe 1986 |
| Talk-move quality | elicit+extend : take-over ratio; revoice count | JMTE 2026; LAK 2025 |
| Feedback TYPE | task/process/self-reg rewarded; generic person-praise penalized | Hattie & Timperley 2007 |
| Praise:reprimand ratio | rate of BSP vs reprimands | Reinke 2008 |
| Redirect intrusiveness | rewarded for least-intrusive that worked | Simonsen 2008 |
| Equity distribution | spread of calls/praise/redirects across NPCs | cold-call equity |
| Noticing accuracy | attend/interpret correctness in Beat 1 | Jacobs 2010 |
| Recovery | composure regained after an error | Ericsson 1993 |

**Critical rule:** feedback is scored by TYPE, not occurrence. "Good job!" (generic) scores lower than "Your strategy of finding a common denominator first is what made that work" (process-level).

### 3.7 Win / Lose Conditions

There is **no hard game-over.** Outcomes are competency states.
- **WIN (Resolve):** the situation resolves only when the player diagnoses the misconception through the NPC's own reasoning (accumulated elicit+extend+revoice), NOT by lecturing (JMTE 2026; LAK 2025).
- **PARTIAL:** meters survive but the misconception was told rather than surfaced. Passes for progression, not for mastery.
- **STALL (soft fail):** Order or Composure bottoms out, segment loops back to a targeted micro-lesson then re-attempt, never a hard fail.
- **Mastery gate (advance condition):** advance a badge only after meeting a fixed competency bar (for example "3 encounters with elicit:take-over >= 2:1 and zero pre-ring cold calls"). Time is the variable; mastery is the constant (McGaghie 2011; Barsuk 2012).

---

## 4. Progression: Regions, Badges, Difficulty Ramp

### 4.1 World Map and Regions

The overworld continent is **Praxis**; Maple Ridge School sits within it. Each Region groups 3 to 4 missions (approximations) that build toward one **Badge**, capped by a **Gym** (multi-objective boss that integrates the Region's sub-skills). Beating a Gym yields the Badge that gates the next Region. Mastered skills resurface in later Regions under new contexts (distributed practice; countering the habit plateau, Hobbiss/Sims/Allen 2020 `[unverified ID]`).

```
                        +---------------------------+
                        |   THE CAPSTONE COLISEUM    |  <- integration bosses
                        |   (all 5 badges required)  |
                        +-------------+-------------+
                                      ^
        +-----------------+-----------------+-----------------+
        |                 |                 |                 |
+-------+------+  +--------+-------+  +------+-------+  +------+--------+
| EQUITY       |  | FEEDBACK FALLS |  | DIAGNOSIS    |  | (regions also |
| CAVERNS      |  | Badge: Mirror  |  | DELTA        |  |  re-test      |
| Badge:Balance|  |                |  | Badge:Insight|  |  earlier      |
+-------+------+  +--------+-------+  +------+-------+  |  badges)      |
        ^                  ^                ^          +---------------+
        |                  |                |
+-------+------+   +--------+-------+
| QUESTIONING  |   | CLASSROOM MGMT |  <-- STARTING REGION
| FOREST       |<--+ TOWN           |
| Badge: Echo  | Badge: Routine     |
+--------------+   +----------------+
```

### 4.2 The Badge Scheme (canonical)

Five earned Badges plus the Capstone. This reconciles the two fragment schemes: the linear 8-badge list is collapsed into the 5-region scheme; the named badges (Routine, Echo, Balance, Mirror, Insight) are canonical.

| Region | Badge | Decomposed practice | Anchor |
|---|---|---|---|
| Classroom Management Town (start) | **Routine** | Routines, BSP, least-to-most redirect, positive expectations | Simonsen 2008; Reinke 2008; McLeskey 2019 |
| Questioning Forest | **Echo** | Wait time, elicit/extend, revoice/lead-discussion | Rowe 1986; Jacobs 2010; LAK 2025 |
| Equity Caverns | **Balance** | Equitable participation distribution, warm vs cold call | Dallimore 2012; Metzger & Via 2022 |
| Feedback Falls | **Mirror** | Formative feedback by TYPE (task/process/self-reg) | Hattie & Timperley 2007; Wisniewski 2020 |
| Diagnosis Delta | **Insight** | Professional noticing (attend/interpret/decide); misconception diagnosis | Jacobs 2010; HLP #4 |
| The Capstone Coliseum | (no new badge; requires all 5) | Full integration under live pressure | Grossman integration; mastery learning |

**Unlock logic:**
- **Decomposition before integration.** Each Region isolates ONE practice with worked-example-first scaffolding; the Coliseum is the only integration content (Grossman 2009).
- **Spaced re-encounter.** Later Regions silently re-score earlier skills (for example Feedback Falls still scores wait time from Questioning Forest); regression below an earlier bar resurfaces a refresher encounter (Hobbiss 2020 `[unverified]`).
- **Mastery, not XP.** Playtime cannot buy advancement; the competency bar must be hit (Ericsson 1993 `[unverified]`).

### 4.3 Deliberate-Practice Difficulty Ramp

Difficulty is **adaptive to recent performance**, kept just beyond current mastery (desirable difficulty), not fixed level numbers (Ericsson 1993 `[unverified]`; Cook et al. 2013 "range of difficulty"). Six dials scale:

| Dial | Early (scaffolded) | Late (faded) |
|---|---|---|
| Objectives | 1 named sub-skill | 3 to 5 integrated, sometimes conflicting |
| Scaffolds (sentence-starters, highlighted cues, decision support) | All on; process-level hints | Withdrawn over attempts (Sweller 2019) |
| NPC count / reactivity | 1 NPC, scripted-branching, low variability | 4 to 5 NPCs, full LLM, emotional, inattentive, inconsistent |
| Time pressure | Untimed; wait-ring is the only timer | Live turn clock; events interrupt |
| Surprise events | None | Meltdown, wrong-answer cascade, side conversation |
| Sycophancy traps | NPC holds firm only on obvious errors | NPC baits with leading openings; flipping = penalty |

Scaffolds fade **within** a mission across retries (attempt 1 shows sentence-starters; attempt 3 shows none) AND **across** the game (later Regions ship fewer supports). Every new Badge opens with an **expert exemplar replay** (representation) before rehearsal, matching representation, decomposition, approximation and worked-example-to-problem fading (Grossman 2009; Sweller 2019). Short, repeatable rounds match the dosage evidence (4 x 10-min sessions changed behavior).

---

## 5. Character Roster

### 5.1 The Player-Teacher

- **Working name:** "The Rookie" (player-named). First-year teacher at Maple Ridge.
- **Customization:** name, pronouns, sprite (skin tone, hair, attire), and a starting **Specialization** that sets opening difficulty: Elementary Generalist, Secondary Content, or Inclusion/Special Ed.
- **Progression resource:** Badges, not levels; each unlocks only at a fixed competency bar (mastery learning).
- **Vitals readout (player-facing summary of the four meters plus key signals):** Wait-Time discipline, Praise:Reprimand ratio, Attention Equity, Feedback Quality.
- **Rationale:** mirrors the documented preservice/early-career audience (Cohen-Wong; Bondie 2023); low-stakes identity reduces the threat that suppresses risk-taking in rehearsal (GPTeach).

### 5.2 The Mentor: Coach Vee (Dr. Vera Okonkwo)

Veteran instructional coach and the pedagogy-of-practice engine. Warm, exact, never vague; speaks only in nameable moves and next steps; refuses to say "good job."

| Loop stage | Coach Vee's function | Anchor |
|---|---|---|
| Pre-mission (Representation) | Plays an expert exemplar replay of the target HLP, then names the sub-skills | Grossman 2009 |
| Mid-mission (Scaffold) | Fading hints: sentence-starters and highlighted cues early, withdrawn as the player succeeds | van de Pol 2010 |
| Post-mission (Debrief) | Three-prompt screen: What happened? Why? What next? | Hattie & Timperley 2007; Eraut 1995 |
| Feedback style | Move-by-move transcript with rubric tags and flagged missed opportunities; names the exact move and the better alternative, never a bare number | Barno 2025 |
| Anti-pattern callout | "You defaulted to redirection four times. Try eliciting." | Teacher Moments AI-coach |

Coach Vee embodies the active ingredient the evidence credits (coaching plus specific feedback, not avatar fidelity). A secondary mentor, **Mr. Hollis** (burned-out-but-kind veteran), appears in later habit-plateau missions to dramatize that experience alone does not improve skill (Hobbiss 2020 `[unverified]`).

### 5.3 Student Roster (LLM-Agent Personas)

Design rules applied to every student: frozen knowledge/misconception state; anti-sycophancy guardrail; injected realism defects (emotion, inattentiveness, grade-bounded language, occasional inconsistency); scoring scores the player, not the NPC.

| # | Student | Archetype | Move that works | Failure mode | Primary HLP / telemetry |
|---|---|---|---|---|---|
| 1 | Sam Park | Disengaged/withdrawn | Wait Time II + warm call | Cold-call shutdown | Equity + wait time |
| 2 | Talia Vance | Dominator (hogs airtime) | Validate briefly + redirect turn | Always-call-Talia | Turn distribution |
| 3 | Deshawn Ellis | Off-task disruptor | Least-to-most continuum + BSP | Public escalation | Praise:reprimand ratio |
| 4 | Mei-Lin Chen | Anxious high-achiever | Process/self-reg feedback | Person-praise | Feedback type |
| 5 | Diego Morales | English-language learner | Extended wait time + revoice | Take-over thinking | Revoice + comprehension check |
| 6 | Noah Brennan | Engineered misconception (1/4 > 1/3 because 4 > 3) | Attend, Interpret, Decide | Restate the rule | Elicit vs take-over; misconception-diagnosed |
| 7 | Riley Tran | Undisclosed need (avoidance reads as defiance) | Diagnose function before responding | Consequence-as-default | Mid-lesson adjust (HLP #6) + HLP #12 |
| 8 | Jordan Webb | Relevance skeptic ("when will I use this?") | Acknowledge + connect to resources + press | Dismiss / over-agree | Relationships + discussion |
| 9 | Priya Anand | Quiet competent (equity blind-spot) | Deliberate equitable call | Forget her | Attention distribution |
| 10 | Marcus Bell | Volatile/frustrated | Affect-first de-escalation, private over public | Match escalation | De-escalation continuum |

Each student's understanding plausibly evolves within a level in response to good teaching (knowledge-development arc), giving observable formative feedback. Anti-sycophancy is the difficulty engine: because students will not simply agree, "solving" requires genuine contingent moves, making each dialogue a puzzle.

### 5.4 Side-Quest NPCs (world-building, optional missions)

These do not carry core HLP scoring; they extend the approximation of practice into difficult-conversation and systems territory (Teacher Moments / Mursion lineage).

- **Principal Adaeze Carter (Administrator):** articulate a pedagogical rationale under evaluative pressure; defend a management plan with the player's own telemetry (praise:reprimand logs, equity metrics).
- **Ms. Robin Halloran (Anxious Parent):** branching difficult conversation; de-escalate, share specific formative evidence, co-plan a next step.
- **Mr. Hollis (Veteran Foil):** dramatizes the habit plateau; the player holds an evidence-based line against folk-wisdom shortcuts.
- **Ms. Tomas (New-Teacher Ally):** cooperative debrief; the player articulates a move to a peer (teaching-to-learn), reinforcing decomposition vocabulary (HLP #19, analyzing instruction).

---

## 6. Scenario / Mission List

Format per mission: Setup, Target behavior, Success criteria, Common wrong moves. Tiers: [SCAFFOLDED] / [FADING] / [BOSS]. Core loop per mission: Representation (expert replay, first mission of a skill only), Decomposition (named sub-skills + live rubric HUD), Approximation (play vs LLM NPCs), Debrief (three prompts), with failed segments looping to a micro-lesson then retry.

### Region 1, Classroom Management Town (Badge: Routine)

- **1.1 "The Bell Ringer" [SCAFFOLDED].** Marco wanders instead of starting the warm-up. Target: implement an entry routine + least-to-most redirect (proximity, nonverbal, brief specific), then one BSP on compliance. Wrong: public reprimand first; vague praise; ignoring until escalation.
- **1.2 "Praise Economy" [SCAFFOLDED].** Three NPCs; live praise-to-reprimand meter starts reprimand-heavy. Target: reach 4:1 BSP-to-reprimand, every praise names the behavior. Wrong: generic "nice"; praising the person; over-reprimanding minor off-task.
- **1.3 "Transition Trouble" [FADING].** Whole-group to small-group transition. Target: stated transition routine + active supervision (circulate) + continuum redirect of drift. Wrong: no signal; standing still; escalation.
- **Gym 1, "Substitute Day" [BOSS].** Five NPCs, no scaffolds, live clock, one surprise side conversation. All required for Badge Routine: (1) state >= 2 positive expectations; (2) praise:reprimand >= 3:1 with BSP; (3) handle the surprise with least-to-most redirect, no escalation; (4) no NPC gets 0 acknowledgments (foreshadows equity).

### Region 2, Questioning Forest (Badge: Echo)

- **2.1 "The Three-Second Pause" [SCAFFOLDED].** One NPC, Priya; wait-time clock is the only HUD. Target: WT-I and WT-II both cross 3s; Priya's response lengthens. Wrong: name in <1s; fill silence; cut off the answer.
- **2.2 "Elicit, Don't Tell" [SCAFFOLDED].** Noah holds the frozen fraction misconception; anti-sycophancy ON. Target: bank >= 3 elicit + >= 2 extend; Noah self-corrects through his own reasoning before any answer is stated. Wrong: telling; leading questions; marking wrong and moving on.
- **2.3 "Revoice and Build" [FADING].** Two NPCs in a mini-discussion. Target: >= 2 revoice moves; link one NPC's idea to the other's; no take-over. Wrong: evaluate ("correct!") instead of revoice; ignore contributions; synthesize for them.
- **Gym 2, "The Discussion Circle" [BOSS].** Four NPCs, live clock, surprise wrong-answer cascade. Badge Echo: maintain wait time on every named turn; elicit+extend (no take-over) to surface the flawed claim; revoice >= 2 and connect across speakers; contain the cascade by routing to evidence, not by declaring it wrong.

### Region 3, Equity Caverns (Badge: Balance)

- **3.1 "Who Gets Called On" [SCAFFOLDED].** Live call-distribution bar chart; eager Talia vs quiet Sam. Target: no NPC at 0 calls; distribution in fairness band; pose-pause-name respected. Wrong: repeat-calling the eager one; naming before posing; never reaching the quiet one.
- **3.2 "Warm Call" [FADING].** Sam carries an anxiety state; raw cold call spikes it. Target: Sam participates AND anxiety stays below threshold; warm-call scaffold used before naming. Wrong: cold-name with no warning; let him off permanently; force through the spike.
- **3.3 "Distribute the Praise and the Redirects" [FADING].** Returns to management under an equity lens (distributed practice). Target: praise AND redirect distributions both in fairness bands. Wrong: praise only the strong NPC; redirect only one or two; equity in calls but not in praise.
- **Gym 3, "Open House Cold Open" [BOSS].** Five NPCs, live clock, surprise interruption of a quiet NPC's turn. Badge Balance: call distribution in band; warm-call the anxious NPC; protect the quiet NPC's turn via redirect; maintain wait time (carried from Echo).

### Region 4, Feedback Falls (Badge: Mirror)

- **4.1 "Beyond Good Job" [SCAFFOLDED].** Lia submits work with a process error; a feedback-type tagger HUD labels each utterance person/task/process/self-reg. Target: >= 1 process-level and >= 1 feed-forward move; zero reliance on person-praise. Wrong: "you're so smart"; a bare grade; vague "revise this."
- **4.2 "Feed Up, Feed Back, Feed Forward" [FADING].** Lia returns with a revision. Target: address all three questions (Where am I going? How am I going? Where to next?); revised reasoning improves. Wrong: only "how am I going" with no goal or next step; dumping every error at once.
- **Gym 4, "The Conferencing Gauntlet" [BOSS].** Three NPCs in sequence, live clock, surprise defensive reaction. Badge Mirror: each NPC gets task/process/self-reg feedback (no person-praise) and a feed-forward step; de-escalate the defensive NPC with process-focused feedback; equitable feedback depth across all three (carried equity).

### Region 5, Diagnosis Delta (Badge: Insight)

- **5.1 "Attend, Interpret, Decide" [SCAFFOLDED].** Theo shows a non-obvious error pattern; HUD enforces the three-step loop. Target: correctly attend, name the misconception, choose a contingent next move; NPC branches on interpretation accuracy. Wrong: skip to a fix; misname the misconception; decide before interpreting.
- **5.2 "Patterns of Error" [FADING].** Three NPCs share the same surface wrong answer for different underlying reasons. Target: name a distinct misconception per NPC; differentiate the next move per student. Wrong: treat identical answers as identical errors; one blanket re-teach; correct the answer not the reasoning.
- **Gym 5, "Diagnostic Rounds" [BOSS].** Four NPCs, live clock, a sycophancy-bait NPC who will falsely "agree" if you assert. Badge Insight: run attend-interpret-decide on each; name each distinct misconception; resist the bait (only contingent moves shift the NPC); deliver differentiated process-level feedback (carried from Mirror).

### The Capstone Coliseum (full integration; all 5 badges required)

- **Capstone A, "The Lesson That Went Sideways" [BOSS].** Five NPCs, every realism defect active, two surprises (a meltdown and a wrong-answer cascade). Integrated: management continuum + wait time + equitable calls + elicit/extend + feedback-by-type + live diagnosis, scored at once. No domain may be robbed to save another.
- **Capstone B, "Parent-Teacher Night" [BOSS, difficult conversation].** A defensive parent NPC; the player must articulate pedagogical rationale. Integrated: affect-sensitive de-escalation + process/feed-forward framing + diagnosis communicated as evidence + composure. Win: the parent's stance shifts through contingent, evidence-based moves, not capitulation.
- **Capstone C, "New Class, Day One" [BOSS, cold start].** A brand-new class; build relationships and learn student resources (HLP #12) WHILE establishing routines and equitable participation from zero, with a withdrawn NPC who tests whether you notice them. Win: routines stated, every NPC engaged including the withdrawn one, at least one student-resource elicited and used in a move.

---

## 7. LLM Agent Dialogue System

### 7.1 Design Stance

Three load-bearing constraints drive every decision: (1) score the player, not the NPC; (2) freeze the NPC's knowledge/misconception state so the model cannot silently know the right answer; (3) structure beats model size (a state machine plus frozen persona JSON plus few-shot exemplars give reproducible behavior and fair scoring). Most engineering is in the prompt schema and the judge, not in model choice.

### 7.2 Persona Schema (frozen, authored, version-controlled)

```json
{
  "persona_id": "noah_g5_fractions",
  "display_name": "Noah",
  "grade_band": "grade_5",
  "subject_context": "comparing_fractions",
  "traits": { "confidence": 0.3, "talkativeness": 0.4, "compliance": 0.5,
              "frustration_tolerance": 0.35, "peer_orientation": 0.6 },
  "knowledge_state": {
    "target_concept": "comparing fractions by common denominator",
    "frozen_misconception": "the fraction with the larger denominator is larger (1/8 > 1/4)",
    "correct_facts_known": ["can name numerator and denominator", "can draw a fraction bar"],
    "facts_NOT_known": ["why denominators must match before comparing"],
    "will_not_invent_beyond": "grade_5 fractions curriculum"
  },
  "hidden_need": "needs to feel safe being wrong; shuts down if corrected bluntly before peers",
  "emotion_baseline": "guarded_neutral",
  "behavior_tendencies": {
    "default_response_length": "short, 1-2 sentences",
    "language_complexity": "grade_5_vocabulary_only",
    "natural_inattentiveness": 0.2,
    "occasional_logical_inconsistency": true
  },
  "escalation_triggers": ["being told 'no, that's wrong' without acknowledgement",
                          "rapid-fire questioning with no wait time",
                          "public comparison to another student",
                          "teacher taking over and solving it"],
  "deescalation_moves": ["revoicing his reasoning before responding",
                         "wait time of 3s or more",
                         "an eliciting question that asks HOW he got the answer",
                         "behavior-specific praise naming what he did"],
  "answer_flip_policy": "Do NOT change your stated understanding just because the teacher asserts or hints at the right answer. Your understanding only shifts when the teacher gets YOU to reason through why denominators must match. Otherwise keep the misconception."
}
```

Anchors: `frozen_misconception` + `answer_flip_policy` defeat the competence paradox and sycophancy; `hidden_need` is what the player must diagnose (Jacobs 2010); `escalation/deescalation` make affect responsive to teacher moves (Simonsen 2008; Metzger & Via 2022); the inattentiveness/inconsistency/language fields inject the four documented realism defects (Martynova 2025); `will_not_invent_beyond` is the hallucination guard.

### 7.3 Runtime (mutable) State

```json
{ "emotion": "guarded_neutral", "understanding": 0.15, "trust_in_teacher": 0.5,
  "engagement": 0.4, "turns_elapsed": 0, "misconception_resolved": false }
```

`understanding` is gated: it rises only when the judge confirms the player produced contingent reasoning-eliciting moves. The model may not raise it on its own. (Note: `trust_in_teacher` and per-NPC `engagement` aggregate up into the class Rapport and Engagement meters of Section 3.3.)

### 7.4 Conversation Loop (judge first, then generate)

```
Godot: player picks a move OR types free text  ->  POST /turn (JSON)
  STEP A  JUDGE (cheap, structured): rule-based prefilter + small-model classify
          of the TEACHER move -> {move_tags, wait_time_ok, quality, meter_deltas}
  STEP B  apply meter_deltas to runtime state (deterministic); enforce gates
  STEP C  STUDENT generation: persona LLM call given frozen persona + NEW runtime
          state + judge verdict -> in-character student utterance
  STEP D  win/loss check on updated state
Godot renders student line + meter changes + coach tip
```

The judge runs **before** student generation, so affect is causal (the student escalates because the judge flagged a take-over, not randomly) and the meter update is deterministic and auditable. Hybrid judge = rule-based prefilter + one small classifier call:
- **Rule layer (free, instant):** wait time (`wait_time_ms >= 3000`), turn distribution/equity tally, menu-move tags (the menu option carries its own tag, so most turns need no LLM), praise:reprimand counters, cold-call-before-pause. This keeps the common case at zero LLM cost for scoring.
- **LLM classifier layer (only for free-typed text):** one cheap schema-constrained call returning a small JSON tag set, no prose.

**Judge tag-to-delta table (fixed, transparent, tunable without re-prompting):**
```
elicit (+contingent, targets_misconception)  -> understanding +0.10
extend                                        -> understanding +0.07
revoice / acknowledge                         -> trust +0.10, engagement +0.05
take_over / tell                              -> understanding +0.00, trust -0.05, engagement -0.10
leading_question                              -> understanding +0.00 (blocked), coach warning fires
behavior_specific_praise                      -> trust +0.08
generic_praise                                -> trust +0.01   (deliberately weak; Hattie/Timperley)
wait_time_ok == false                         -> trust -0.05, frustration up
```

### 7.5 Guardrails

1. **Anti-sycophancy / no unrealistic compliance.** `answer_flip_policy` is restated verbatim in the student prompt; the judge's `targets_misconception` flag is the only thing that lets `understanding` cross the resolve threshold. Tested with leading prompts. (Defends the 15 to 30 pp flip, arXiv:2506.10297 `[unverified]`.)
2. **Frozen knowledge state / competence paradox.** The student prompt walls off the model's general competence behind the persona record: it knows only `correct_facts_known`, holds `frozen_misconception`, and does not know the target answer until `misconception_resolved` is true.
3. **Bounded persona drift.** The student call is stateless on persona: every turn re-sends the frozen record + current runtime state. History is included only as the last N dialogue turns for coherence, never as the source of truth for traits.
4. **Bias checks.** Hand-curated persona library; an authoring-time lint flags clinical/ADHD over-representation (arXiv:2410.14012 `[unverified]`) and any behavior keyed to name/demographic surface cues. Names and behavior are decoupled fields.
5. **Curriculum fact guard.** A retrieval-free allowlist; the student deflects off-curriculum facts ("we didn't do that yet") rather than invent. A post-gen validator regex-scans for out-of-scope terms and regenerates once on a hit.
6. **Post-generation validator (deterministic).** Reject and regenerate if the student volunteers correct reasoning while `misconception_resolved=false`; if length/vocabulary exceeds the grade band; clamp emotion transitions to at most one step per turn unless an escalation trigger matched.

### 7.6 Godot to Backend JSON Contract

One endpoint, `POST /turn`. Godot owns the timer and the persona/runtime cache; the backend is stateless across calls except for the model.

Request (Godot to backend):
```json
{ "session_id": "sess_8842", "scenario_id": "fractions_intro_v2",
  "target_behavior": "elicit_student_thinking", "active_persona_id": "noah_g5_fractions",
  "frozen_persona": { "...persona record..." },
  "runtime_state": { "emotion":"guarded_neutral","understanding":0.15,"trust_in_teacher":0.5,
                     "engagement":0.4,"turns_elapsed":3,"misconception_resolved":false },
  "teacher_move": { "input_mode":"free_text", "menu_tag":null,
                    "text":"Can you show me how you decided 1/8 is bigger than 1/4?",
                    "wait_time_ms":4200, "addressed_persona_id":"noah_g5_fractions" },
  "dialogue_tail": [ {"speaker":"teacher","text":"Which is bigger, 1/8 or 1/4?"},
                     {"speaker":"noah","text":"1/8, because 8 is bigger than 4."} ],
  "model_profile": "hybrid" }
```

Response (backend to Godot):
```json
{ "session_id": "sess_8842",
  "judge": { "move_tags":["elicit"], "is_contingent":true, "targets_misconception":true,
             "feedback_type":"process", "wait_time_ok":true,
             "one_line_reason":"Asked Noah to externalize his reasoning instead of correcting him." },
  "meter_deltas": { "understanding":0.10, "trust_in_teacher":0.10, "engagement":0.05, "emotion":"warming" },
  "runtime_state": { "emotion":"warming","understanding":0.25,"trust_in_teacher":0.60,
                     "engagement":0.45,"turns_elapsed":4,"misconception_resolved":false },
  "student_utterance": { "speaker":"noah",
     "text":"Um... 8 pieces is more than 4, so I drew 8 little boxes. But... they're skinnier?",
     "emotion_shown":"thinking" },
  "coach_tip":"Good eliciting move and you gave wait time. Noah just noticed the pieces are 'skinnier'. That crack is the misconception. Press on it.",
  "win_state": { "status":"in_progress", "resolved_objectives":["elicited_reasoning"],
                 "remaining":["misconception_resolved"] },
  "telemetry": { "move_tags":["elicit"], "wait_time_ms":4200,
                 "addressed_persona_id":"noah_g5_fractions", "judge_cost_tokens":180 } }
```

**Win detection (deterministic; the LLM never declares victory):**
```
misconception_resolved := true WHEN
   understanding >= 0.80
   AND resolving turn's judge had targets_misconception == true
   AND most-recent move_tags intersect {elicit, extend, revoice} is non-empty
   AND NOT (resolving turn was take_over/tell)
```
Multi-objective wins (per mission) add equity (`no single persona addressed > 60% of turns`), trust maintenance, and bonus feedback-quality/wait-time conditions. Fail conditions (shutdown, take-over spiral) loop to a segment rehearsal, not a hard game-over.

### 7.7 Model Options (cloud Claude vs local Ollama on RTX 5060 Ti)

Both paths implement the same two-call structure; the `model_profile` field selects the backend.

| Profile | Judge call | Student call | Notes |
|---|---|---|---|
| `cloud_claude_haiku` | Claude Haiku, JSON-constrained, prompt-cache the frozen persona + rubric | Claude Haiku or Sonnet | Cheapest consistent cloud path; cache the invariant prefix |
| `local_ollama` | local 7-8B (`qwen2.5:7b-instruct` or `llama3.1:8b`) with `format: json` | same local model, persona role | Runs on the 5060 Ti 16GB; keep model resident; prefer an instruct/chat model over the coder model; do not push 14B with desktop apps open |
| `hybrid` (recommended default) | local 7B judge (deterministic, cheap, high-volume) | cloud Sonnet student (best affect, low-volume) | Judging is the high-volume call; generation is the low-volume quality call |

Cost/consistency tactics: menu moves skip the judge LLM entirely; judge output is fixed-schema JSON; prompt-cache the invariant prefix; temperatures judge = 0.0 (fair scoring), student = 0.6 to 0.8 (natural variability + injected defects).

---

## 8. Art Direction (Pokemon-style pixel look)

### 8.1 Resolution and Tile Decisions

- **16x16 base tile** (canonical Gen-3/Gen-4 overworld grid; one desk = 1 tile, one student = 1 tile; maximizes free-asset compatibility).
- **16x32 character sprites** (Gen-4 "tall trainer" look; room for readable faces, which matters for affect).
- **480x270 logical viewport**, integer-scaled x3 to 1440x810 (or x4 to 1920x1080 with letterboxing). Project settings: `display/window/stretch/mode = viewport`, `scale_mode = integer`, `rendering/textures/canvas_textures/default_texture_filter = Nearest`.

### 8.2 Palette Mood (note: "Zone" here is an art term, distinct from gameplay Regions)

Warm institutional, not saturated outdoor route. Lean Gen-4 indoor tones. Constrained palette of roughly 32 to 48 colors against a fixed CC0 ramp (Resurrect 32 or AAP-64).

| Art zone | Mood | Anchor hues |
|---|---|---|
| Hallway | Cool neutral, fluorescent | desaturated teal-grey floors, cream walls, locker blue |
| Classroom | Warm, focused | oak/amber desks, chalk-green/whiteboard front wall, soft daylight |
| Encounter screen | Spotlight on the student | dim vignette periphery, warm key light on the student sprite, deep-navy UI panel with cream text |

The four meters deliberately break the environment palette (saturated green/amber/red) so they pop as HUD, exactly like Pokemon HP bars.

### 8.3 Sprite and Animation Needs

- **Overworld characters (16x32):** 4 directions x 3 frames (idle/contact, step-left, step-right) = 12 frames, laid out 3-wide x 4-tall (48x128 per character). One reusable 1-frame emote overlay (exclamation/sweat/heart).
- **Encounter portraits (64x64 or 96x96, the hero asset):** minimum 6 affect states (neutral, engaged, confused, frustrated, withdrawn, excited), each with a 2-frame idle bob.
- **Tilesets (16x16):** interior (floors, walls + tops, animated 3-frame doors, windows, lockers, board, desks, chairs, shelves, posters, plants, bin, projector) and hallway (floor strips, locker banks, boards, fountain, stairwell, exits); a 9-slice UI box tileset.
- **UI/FX:** dialogue frame (9-slice), blinking cursor, meter fills, 5 badge icons (Routine/Echo/Balance/Mirror/Insight) plus a Capstone seal, 2-frame advance arrow, Pokemon-style transition wipe.
- **Animation system:** `AnimatedSprite2D` + `SpriteFrames` for characters and affect states; `AnimationPlayer` for UI choreography. Walk frames are driven by movement state so feet sync to grid steps.

### 8.4 Asset Sourcing (free/CC0 vs generate)

| Asset | Source | License | Note |
|---|---|---|---|
| Interior tileset | Kenney Roguelike/RPG; LPC interiors | CC0 / CC-BY-SA | Kenney CC0 preferred; LPC for proto only (copyleft) |
| Character walk sprites | LPC Universal Sprite Sheet | CC-BY-SA / GPL | Great for diverse personas; copyleft if shipped |
| Hallway props, UI frames, cursor, badges | Kenney top-down + UI packs | CC0 | Recolor to navy/cream theme |
| Palette ramp | Resurrect 32 / AAP-64 | CC0 | Author everything against this |
| **Student affect portraits (6 states)** | **GENERATE** | n/a | The emotional core; pixel-art generate at 64x64, hand-clean to palette |
| Emote bubbles, transition wipes | Generate or Kenney | mixed | Trivial |

Rule of thumb: environment + walk cycles = Kenney CC0 first, LPC for prototyping only; student affect portraits = generated hero asset. If shipping, prefer Kenney CC0 to avoid CC-BY-SA copyleft contaminating the project. The exec/MCP path cannot generate pixel art; portraits come from an image-gen step then editor import.

---

## 9. Godot 4 Technical Architecture (Godot 4.6.3)

### 9.1 Scene Tree

```
Main.tscn (root, thin bootstrapper)
|- SceneStack (Node)            # holds the active gameplay scene; swapped at runtime
|   |- <current scene>          # Overworld.tscn OR Encounter.tscn
|- UILayer (CanvasLayer)        # persistent overlays
|   |- TransitionRect (ColorRect + wipe.gdshader)
|   |- DialogueUI.tscn          # instanced, hidden by default
(Autoloads, not in tree: GameState, SceneRouter, DialogueManager, LLMClient, AudioManager)
```

Overworld.tscn uses Godot 4 **TileMapLayer** nodes (the old TileMap is deprecated): Ground, Walls (collidable), Objects, Overhead (drawn above player), under a y-sorted node holding Player (CharacterBody2D, grid-mover) and StudentNPCs, plus EncounterTriggers, Camera2D (integer-snapped follow), and SpawnPoints (Marker2D).

Encounter.tscn: ClassroomBackdrop (Sprite2D, dim vignette), StudentActor (AnimatedSprite2D, affect-state-driven), MeterPanel (Engagement / Order / Rapport as TextureProgressBar; Composure as the player HP bar), TeachingMoveMenu (the seven moves), DialogueAnchor, EncounterFX.

### 9.2 Autoloads

| Autoload | Responsibility |
|---|---|
| **GameState** | Single source of truth: badges[], unlocked scenarios, per-student progress, current scene, settings; the saved data |
| **SceneRouter** | `change_scene(path, spawn_point, transition)`; owns TransitionRect choreography (fade out, free old, instance new, place player, fade in) |
| **DialogueManager** | Queues/streams text, typewriter reveal, choice prompts; emits `line_finished`/`choice_made`; feeds authored and LLM-streamed text |
| **LLMClient** | Wraps `HTTPRequest`; POSTs the `/turn` contract; parses into dialogue + meter deltas + new affect; emits `reply_ready` |
| **AudioManager** | BGM crossfade per zone, SFX bus, text blip |

Init order in Project Settings -> Autoload: GameState first, LLMClient after it (reads config), SceneRouter among the data nodes.

### 9.3 Key Scripts (sketches)

Grid movement (tile-locked tweened steps, not free physics): poll held keys in `_process`, set facing + walk anim, compute the target tile, query `TileMapLayer_Walls` cell + a `students_occupied` set in GameState for blocking, tween `global_position` over `step_time` (~0.14s), then `_check_encounter_tile()`. Pressing `ui_accept` while facing a StudentNPC calls `SceneRouter.change_scene("Encounter.tscn", {student_id})`. Remap accept/cancel to Z/X for Game Boy muscle memory.

DialogueManager is a dumb-view + state split: it owns the line queue and reveal logic; DialogueUI handles typewriter, advance arrow, and choice cursor.

LLMClient `send_move(payload)` POSTs JSON via `HTTPRequest` to `endpoint` (default `http://127.0.0.1:8000/turn`), parses the response, clamps meters 0..100 on the Godot side, shows a "thinking..." state, uses a short timeout. For the first milestone, a single response with local typewriter reveal; streaming token reveal is deferred.

Save/load: versioned JSON under `user://` (`save_<slot>.json`), human-debuggable. Badge award flow: encounter completion -> GameState checks the mastery thresholds -> appends the badge -> SceneRouter plays a badge-get fanfare overlay -> autosave. Badges gate `unlocked_scenarios` (locked classroom doors), giving the gym-badge loop.

### 9.4 Folder Plan

```
res://
|- project.godot                 # viewport stretch, integer scale, Nearest, 480x270
|- autoload/  GameState.gd SceneRouter.gd DialogueManager.gd LLMClient.gd AudioManager.gd
|- scenes/
|   |- Main.tscn/.gd
|   |- overworld/  Overworld, Player, StudentNPC (.tscn/.gd each)
|   |- encounter/  Encounter, MeterPanel, TeachingMoveMenu
|   |- ui/         DialogueUI, TransitionRect (+ wipe.gdshader), BadgeGet
|- data/
|   |- students/   noah_g5_fractions.tres ...   # StudentData Resource (links frozen persona JSON)
|   |- scenarios/  room101.tres ...             # ScenarioData: students, win thresholds, badge_id
|   |- moves.tres                                # TeachingMove definitions + tooltips
|   |- persona_library/ *.json                   # frozen persona records (Section 7.2)
|   |- judge_rubric.json                          # tag -> delta table (Section 7.4)
|   |- win_conditions/ *.json                      # per-scenario gates (Section 7.6)
|- assets/  tiles/ sprites/ ui/ audio/
|- tools/   llm_backend/   # FastAPI or Ollama gateway on JACOB; not shipped in the pck
```

Custom Resource classes (`StudentData`, `ScenarioData`, `TeachingMove`) keep content data-driven and Inspector-editable, so new students/classrooms are `.tres` files, not code.

### 9.5 godot-mcp Workflow

Confirmed: `C:\Users\jewoo\Projects\godot-mcp` (built) and `C:\Users\jewoo\godot\godot.exe` (4.6.3), registered user-scope.
1. Scaffold scenes via MCP (`create_scene`, `add_node`) for tree boilerplate.
2. Hand-author GDScript and TileSet resources in the editor (`launch_editor`); MCP is weaker at resource/TileSet authoring.
3. Iterate with `run_project` + `get_debug_output` to catch the `:=` Variant-inference crash gotcha and null-node errors fast.
4. Run `update_project_uids` after moving/renaming scripts (4.6.3 is strict about UIDs).
5. Keep MCP for structural scaffolding + run/debug; keep the editor for art import (Nearest filter, no mipmaps), TileSet painting, and SpriteFrames.

---

## 10. First-Playable (Vertical Slice) and Roadmap

### 10.1 M1 Vertical Slice Scope

Goal: walk a teacher around one classroom, bump into one student, enter the encounter, pick a teaching move, see the student react with stubbed-then-LLM dialogue + meter changes, resolve, get a badge, and persist across restart.

| # | Task | Done-when |
|---|---|---|
| 1 | Project config: 480x270, integer stretch, Nearest filter | Pixels crisp at x3, no blur |
| 2 | One classroom map: Ground/Walls/Objects/Overhead TileMapLayers (Kenney CC0) | Player collides with desks/walls |
| 3 | Player grid movement + 4-dir walk (LPC), Camera2D follow | Tile-locked stepping, bump anim |
| 4 | One StudentNPC (Noah); `ui_accept` while facing triggers SceneRouter | Fade-wipe into Encounter.tscn |
| 5 | Encounter scene: backdrop + 1 affect portrait + Engagement/Order/Rapport + Composure + move menu | Menu navigable with cursor |
| 6 | LLMClient hits a STUBBED `/turn` returning canned `{judge, meter_deltas, student_utterance, coach_tip}` | "Elicit" updates meters + shows reply via typewriter |
| 7 | Resolve gate: misconception_resolved via elicit path -> award Badge Echo -> BadgeGet overlay -> overworld | Fanfare plays; door logic reads the badge |
| 8 | GameState save on badge; load on boot | Restart preserves badge + student progress |
| 9 | MCP loop wired: scaffold via create_scene/add_node, run_project + get_debug_output | Headless run launches M1 from the agent |

Deferred past M1: multiple classrooms/hallway hub, full 6-state portraits + idle bobs, streaming token reveal, real LLM backend on JACOB Ollama, audio polish, multiple badges/gating, NPC schedules.

### 10.2 Phased Roadmap

- **Phase 1 (M1, vertical slice):** the table above. One Region-2 mission ("Elicit, Don't Tell") end to end with a stubbed backend and one persona.
- **Phase 2 (one full Region):** Questioning Forest complete (3 missions + Gym Echo), real `hybrid` LLM backend (local 7B judge + cloud/local student), the full judge rubric and win-condition JSON, fading hints, three-prompt debrief. Validate the rubric engine's reproducibility across players.
- **Phase 3 (breadth):** all five Regions + the five Badges, the equity tracker as a first-class HUD, distributed re-encounter wiring, the bias-lint authoring tool, the curriculum fact guard and post-gen validator.
- **Phase 4 (integration + side quests):** the Capstone Coliseum (A/B/C), side-quest NPCs (Principal, Parent, Hollis, Tomas), adaptive difficulty dials, full 6-state affect portraits, audio.
- **Phase 5 (research instrumentation):** telemetry export pipeline (per-turn move tags, wait-time ms, equity bands, feedback-type counts), session logging for study use, and an evaluation harness (Section 11).

---

## 11. Open Questions, Risks, and Research-Evaluation Angle

### 11.1 Research Framing

Chalk & Chance is both a game and a research artifact. Its adoption argument: every objective is anchored to a named TeachingWorks HLP and scored as discrete telemetry, so scores map onto what teacher-prep programs already assess, and the mixed-reality transfer evidence supports the expectation that in-sim behavior change transfers, with the explicit caveat that the active ingredient is tight, specific, immediate feedback and coaching, not graphical fidelity. The novel contribution over the prior teacher-sim lineage (simSchool, TeachLivE/Mursion, MIT Teacher Moments, SchoolSims/Quest2Teach) is replacing the human "interactor" puppeteer with validity-engineered LLM personas while keeping the coaching-feedback loop that the evidence actually credits.

### 11.2 Risks

- **Citation integrity.** Several anchors are flagged `[unverified]`: Ericsson 1993 (ID), Grossman 2009 (ID/venue), Hattie & Timperley 2007 (ID), Schon 1983/1987 (books, no single work ID), Sims & Fletcher-Wood 2020 and Hobbiss 2020 (IDs), the TeachLivE transfer specifics, and the LLM-student arXiv preprints (some future-dated relative to cutoff). Run `refcheck` before any publication-facing use; lead effectiveness claims only with confirmed anchors.
- **LLM fidelity drift.** Sycophancy, competence paradox, and persona drift threaten scoring fairness. Mitigation is structural (frozen persona, judge-before-generate, deterministic gates, post-gen validator), but each guardrail needs empirical stress-testing with adversarial/leading prompts.
- **Construct validity of the rubric.** The elicit/extend/take-over classifier must agree with human coders. A small classifier can mis-tag free-typed teacher text; menu-first design reduces but does not eliminate this.
- **Cost and latency.** Even the hybrid profile pays for the cloud student call; the local-only profile risks VRAM contention on the 16GB 5060 Ti with desktop apps open. Menu-first scoring and prompt caching are the primary controls.
- **Bias in personas.** The hand-curated library and authoring lint guard against the documented ADHD-skew and name-keyed behavior, but the library needs review by content and equity experts before any classroom deployment.
- **Transfer is unproven for THIS artifact.** The MR transfer evidence is for puppeteered avatars, not LLM personas in a 2D arcade frame. Treat transfer as a hypothesis to test, not a claim.

### 11.3 Open Questions

1. **Inter-rater reliability:** what is the agreement between the LLM judge's move tags and trained human coders, and what is the minimum model size that holds it?
2. **Does the resolve gate measure the right thing?** Does "misconception resolved through the student's own reasoning" correlate with real responsive-teaching competence, or can players game it?
3. **Dosage:** does the 4 x 10-minute pattern that moved behavior in MR studies hold for short arcade rounds here?
4. **Equity-as-a-metric externalities:** does foregrounding attention distribution as a score change real-classroom call patterns, or only in-game behavior?
5. **Affect realism vs scoring stability:** how much student temperature/variability can be added before it harms reproducible scoring?
6. **Evaluation design:** a candidate study is a block-randomized comparison (mirroring the Cohen-Wong design) of Chalk & Chance + coach feedback vs the same scenarios without the move-tagged feedback layer, measuring change in a target enacted behavior (for example high-information feedback or wait time) in a subsequent real or simulated lesson.

---

### One-line summary

Walk a Pokemon school; every classroom door is one high-leverage practice; "battles" are read-act-observe dialogues against sycophancy-resistant LLM students; you win by surfacing thinking rather than lecturing; you advance by mastering one decomposed behavior at a time (the five Badges: Routine, Echo, Balance, Mirror, Insight, then the Capstone Coliseum), with Coach Vee giving typed, fading, next-step feedback every round, each mechanic anchored to the cited evidence and built in Godot 4.6.3.
