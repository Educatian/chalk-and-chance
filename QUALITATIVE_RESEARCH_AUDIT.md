# Qualitative-Research Alignment Audit

Does Chalk & Chance reflect the *qualitative* research from teacher education / classroom
management / teacher simulation, or only the measurable "high-leverage practice" strand?
Honest answer: the game strongly reflects the **practice-based, behavioral/cognitive**
strand, but **under-represents the relational, cultural, identity, and interpretive**
strands that dominate qualitative teacher-ed scholarship. Details below.

## Coverage matrix

| Qualitative theme (research) | In game | Status |
|---|---|---|
| Decomposition / approximations of practice; rehearsal (Grossman et al. 2009) | one move per door, encounters, gym integration, deliberate-practice fade | **Reflected** |
| Withitness, overlapping, momentum, group alerting (Kounin 1970) | proximity + withitness live layer, period clock, momentum drift | **Reflected** |
| Classroom discourse: eliciting, revoicing, wait time (Cazden; Rowe 1986) | 7 moves + Wait-Time ring | **Reflected** |
| Equity of participation / who gets called on (qualitative + Dallimore) | equity "Engaged k/N" tracker + objective | **Reflected** |
| De-escalation, least-intrusive response (management lit) | differentiated win (Deshawn/Marcus), interrupt triage | **Reflected** |
| Professional noticing as ATTEND-INTERPRET-DECIDE (Jacobs 2010) | "read the student" framing; gym targeting | **Partial** (interpretation is deterministic, not ambiguous) |
| Culturally responsive classroom management (Weinstein, Tomlinson-Clarke & Curran 2004) | nothing on culture, ethnocentrism, context, culturally appropriate strategies | **Missing** |
| Warm demander: warmth + high expectations (Kleinfeld 1975; Bondy & Ross) | "Rapport" meter is thin; no warmth+demand combination, no relationship building | **Missing / thin** |
| Asset framing & funds of knowledge (Moll & Gonzalez) vs deficit framing | personas are defined by deficits; HLP#12 "learn/use student resources" is not a mechanic | **Missing** |
| Care ethic (Noddings); relationships over time | each period is isolated; no cumulative trust/relationship | **Missing** |
| Teacher emotion / identity / vulnerability (Hargreaves) | "Composure" = a thin HP bar | **Partial** (reductive) |
| Interpretive judgment: rarely one right move; context-dependent | each student has ONE deterministic win move; "wrong" moves nudged | **Missing / at-risk** |
| Reflection-on/in-action, reframing (Schon 1983) | debrief = scored summary + one coach line | **Partial** (shallow) |
| Student voice / agency / co-construction | students are objects to be "resolved" | **Missing** |
| Home-school, families, community context | parent NPC designed in GDD, not built | **Missing** |
| The problem of enactment; transfer is hard (Kennedy 1999) | flagged as a hypothesis in GAME_CONCEPT 11 | **Acknowledged** |

## The three biggest risks (where the design may contradict qualitative findings)

1. **Deterministic "one right move" per student** contradicts the qualitative consensus that
   expert teaching is interpretive and context-dependent, with multiple defensible responses.
   As built, the game can teach "guess the single correct move," the opposite of reflective
   judgment. (Mitigate: allow 2-3 viable paths per student; reward sound reasoning, not a
   single key; add ambiguous students whose "need" must be interpreted, not matched.)
2. **Culture is absent.** The dominant qualitative strand (Weinstein 2004; warm demander;
   funds of knowledge) treats management as cultural and relational. The roster and scenarios
   are culture-neutral and deficit-framed. (Mitigate below.)
3. **No relationships over time / no student assets.** Qualitative work centers trust built
   across time and students' resources; the game is single-period and deficit-anchored.

## Recommendations (map each gap to a mechanic/scenario)

- **Asset framing + funds of knowledge** [high]: add a "learn a student's resource" move /
  pre-class info, and make some encounters resolve by *connecting to a student's strength or
  interest* (HLP#12), not by fixing a deficit. Reframe persona files with an `assets` field.
- **Culturally responsive management scenario** [high]: a scenario where the "right" move
  depends on knowing the student's cultural/community context; model Weinstein's components
  (recognize assumptions, know students, caring community). Add a "check your assumption"
  beat in noticing.
- **Multiple viable responses + ambiguity** [high]: change win logic from one `win_moves`
  set to weighted paths; add an "ambiguous need" student (the GDD's Riley) whose function
  must be interpreted and where two different reads can both work.
- **Warm demander / relationships over time** [med]: a persistent per-student relationship
  meter that carries across periods (not reset); warmth + high-demand both required; cold
  compliance is not a win.
- **Deeper reflection** [med]: a debrief that asks the player to choose what they noticed /
  what they would reframe (Schon), not just shows a score.
- **Student voice** [med]: let students push back or offer their own goal; resolution as
  co-construction, not compliance.
- **Teacher identity/emotion** [low]: make Composure relational (recovers through connection,
  not just time), with reflective prompts.

## Verdict

The simulation is a strong, evidence-grounded trainer for the **decomposable, observable**
practices (Kounin/Grossman/discourse/equity/de-escalation) and is honest that transfer is a
hypothesis. To match the *qualitative* teacher-education literature it should add the
**cultural, relational, asset-based, and interpretive** dimensions, and soften the
single-right-answer mechanic, which is currently its sharpest mismatch with that literature.

## Addressed in build (2026-05-29)

The high- and medium-priority gaps above are now implemented as mechanics, not just docs:

| Gap (was) | Now in game |
|---|---|
| Asset framing & funds of knowledge (**Missing**) | Every persona has an `assets` / `asset_hint` field; a new **Connect** move *notices* a student's real-world strength then *bridges* the content to it (Moll & Gonzalez). |
| Interpretive judgment / one-right-move (**At-risk**) | Connect-resolvable students (Noah, Jordan, Diego, Riley, Sam) now have **two defensible routes** - surface reasoning (discourse moves) **or** connect to an asset - so the game no longer trains "guess the single key." |
| Professional noticing ATTEND-INTERPRET-DECIDE (**Partial**) | Connect's first press is an explicit **notice/interpret beat** that surfaces the student's asset (and, for Riley, reframes the *function* of the behavior) before you decide. |
| Culturally responsive management (**Missing**) | New scenario `culturally_responsive_intro` (Weinstein et al. 2004) assembles asset-rich students with a **`connect_min` objective** that forces you to learn each student's funds of knowledge and check your assumption before correcting. |
| Warm demander / relationships over time (**Missing/thin**) | A persistent per-student **Bond** meter (GameState.relationships) **carries across periods**, is built by connecting + appropriate demand, eroded by cold takeover (Tell), and gives a trust head-start next period. Wins are framed as warm-demander when the bond is also high. |
| Care ethic; relationships over time (**Missing**) | Same persistent Bond - the classroom is no longer memoryless between periods. |
| Reflection-on/in-action (**Partial/shallow**) | The debrief now opens with a **reflection-on-action** prompt (Schon 1983): the player names what stays with them (who I didn't reach / a moment I'd reframe / an asset I connected to) before any score; choices are logged. |
| Student voice / co-construction (**Missing**) | Connect resolutions are voiced in the student's *own world* (their `connect_line`), i.e. co-constructed meaning rather than compliance. |

Verified by `scenes/dev/QualTest` (12 checks). Still open / future: families & community-context NPCs, emotion/identity depth beyond Composure, and a real (non-stub) LLM to make interpretation genuinely ambiguous rather than scripted.

## Sources

- Weinstein, Tomlinson-Clarke & Curran (2004). Toward a Conception of Culturally Responsive
  Classroom Management. Journal of Teacher Education, 55(1), 25-38.
  https://journals.sagepub.com/doi/10.1177/0022487103259812
- Bondy & Ross. The Teacher as Warm Demander.
  https://www.semanticscholar.org/paper/The-Teacher-as-Warm-Demander-Bondy-Ross/2b90768cdc516008a1d3b178e067b840d6fd92ef
- Warm and demanding teacher practices: a qualitative synthesis of urban classroom management.
  https://www.sciencedirect.com/science/article/pii/S0742051X24004311
- Canonical (run refcheck): Grossman et al. 2009; Kounin 1970; Jacobs, Lamb & Philipp 2010;
  Schon 1983; Moll & Gonzalez (funds of knowledge); Noddings (care); Hargreaves (emotion);
  Kennedy 1999 (the problem of enactment).
