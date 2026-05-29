# Chalk & Chance - Game Enhancement Roadmap

Prioritized advancement list for the game itself. Tiers are P0 (core depth that makes it a
real teaching-rehearsal tool) down to P4 (polish, research, deployment). Each item notes
impact / effort and ties to the design docs / evidence where relevant.

Current state (shipped): 4 meters, 7 teaching moves + Wait-Time ring, 10 research-grounded
LLM-persona students (stubbed), live classroom management (proximity + withitness), period
clock + Composure + interrupt triage, scored debrief + badges, data-driven scenes (4
formats: U-shape / rows / clusters), mission hub, evidence-based seating, 2x art, landing
page.

---

## P0 - Core depth (do these first; they make it a teaching sim, not a demo)

1. **Differentiated win conditions per student/practice** [HIGH impact / MED effort]
   Today every encounter resolves the same way (elicit -> understanding). Make each persona
   score the move that actually works for them (per PERSONAS_EVIDENCE.md):
   Deshawn = least-to-most redirect; Mei-Lin = process (not person) feedback; Talia =
   validate + redistribute the turn; Marcus = affect-first private de-escalation; Sam =
   warm call + wait time; Diego = wait time + representation; Riley = diagnose the function
   first; Jordan = establish relevance then press; Priya = deliberate equitable call.
   Encode `win_moves` / `target_meter` in each persona JSON; the judge checks them.

2. **Real LLM backend wired in** [HIGH / MED-HIGH]
   Replace the stub: local 7B judge (Ollama, JSON, temp 0) + student generation (cloud
   Claude or local), frozen-persona anti-sycophancy, free-typed teacher input, the
   judge-before-generate loop and guardrails already specified in GAME_CONCEPT.md 7. Add an
   in-browser WebLLM option for a $0 / on-device path.

3. **Equity / turn-distribution tracker as a first-class score** [HIGH / MED]
   Track who has been called on / praised / redirected across the seated class; surface it
   as a HUD panel and score it (Dallimore cold-call equity; Kounin group alerting). Makes
   Talia/Priya/Sam meaningfully different in the room, not just in dialogue.

4. **Per-format objective metrics** [MED / MED]
   Extend the objectives tracker beyond attention/disruptions/composure to the signals each
   format is about: wait-time count, elicit:tell ratio, equity spread, redirect
   intrusiveness, feedback-type mix. Debrief then scores the right thing per scene.

---

## P1 - Orchestration & environment depth (ENVIRONMENT_MECHANICS.md)

5. **Routine buffer** [MED / LOW] An opening "establish routines" beat that builds an Order
   buffer absorbing later disruptions (Emmer & Evertson; Lemov).
6. **Seating-chart planning phase** [HIGH / MED] Before the period, pick the arrangement
   (rows/U/clusters) and seat students; adjacency effects (Talia next to Deshawn = chatter;
   a calm peer buffers Marcus). Directly rehearses "task dictates arrangement."
7. **Attention curve + momentum** [MED / MED] Period-long attention decay, post-lunch dip,
   loss-of-momentum penalty for dead time / slow transitions (Kounin momentum/smoothness).
8. **Whole-class moves from the overworld** [MED / MED] A quiet signal / group-alerting
   action to reset noise, so management is not only per-student proximity.
9. **Persona-specific off-task behavior** [MED / MED] Dominator pulls neighbors off task;
   withdrawn goes silent (not loud); volatile spikes fast. Off-task is not uniform.
10. **More interrupt variety + materials/tech events** [LOW / LOW] Projector dies, fire
    drill, PA, handout distribution; rewards backup routines.

---

## P2 - Content & progression

11. **More subjects/scenes** [MED / LOW-each] Beyond fractions: reading comprehension,
    science argumentation; a transitions/stations format. Each is one scenario JSON +
    persona tweaks.
12. **Region map + badge-gated campaign** [MED / MED] The GDD's five regions
    (Routine/Echo/Balance/Mirror/Insight) as a progression; unlock missions by badge.
13. **Multi-student "gym" boss encounters** [HIGH / HIGH] Handle 4-5 students at once with
    competing demands (the GDD capstones); the real test of orchestration.
14. **Deliberate-practice difficulty ramp** [MED / MED] Scaffolds (sentence starters,
    highlighted cues) that fade across attempts/missions (Ericsson; Sweller fading).

---

## P3 - Polish & feel ("juice")

15. **Audio** [MED / MED] Per-scene BGM, SFX (text blips, move feedback, badge fanfare,
    footsteps), interrupt sting.
16. **Visual juice** [MED / MED] Pokemon-style transition wipe between overworld/encounter,
    meter-fill tweens, feedback flashes, portrait affect cross-fades, emote pop-in.
17. **Typewriter dialogue + portrait bob** [LOW / LOW] Streamed text reveal; idle bob; affect
    swap on each line.
18. **Environment variety** [LOW / MED] Day/night tints, more decor and tilesets, multiple
    classrooms/hallway hub.
19. **Player customization** [LOW / LOW] Name, pronouns, sprite, starting specialization.

---

## P4 - Research, deployment, accessibility (it's also a research artifact)

20. **Telemetry export** [HIGH for research / MED] Per-turn move tags, wait-time ms, equity
    bands, feedback-type counts -> CSV / xAPI for study use (GAME_CONCEPT.md 10/11).
21. **Judge validity check** [HIGH for research / MED] Inter-rater agreement of the LLM move
    classifier vs trained human coders; report kappa; tune.
22. **Web export + WebLLM** [MED / MED] Godot HTML5 build behind the landing page CTA;
    in-browser students for a zero-cost demo.
23. **Accessibility** [MED / LOW-MED] Colorblind-safe meters, font scaling, remappable keys,
    captions, reduced-motion.
24. **Save profiles + settings menu** [LOW / LOW] Multiple slots, audio/text-speed/key
    settings, progress per student.

---

## Tech-debt / robustness (do alongside)

- Proper Godot **TileSet/TileMapLayer** instead of per-tile Sprite2D (perf, y-sorting,
  painting); node pooling for large classes.
- **Scenario + persona schema validation** (catch bad JSON at load); a tiny scenario editor.
- Encounter/overworld **shared meter state** (carry Composure between the room and encounters
  instead of separate values).
- Automated **regression tests** beyond SmokeTest/OverworldTest (per-scene load, objective
  scoring, judge rubric).

---

## Recommended next 5 (best impact-to-effort right now)

1. P0-1 Differentiated win conditions per student (depth + uses the evidence already mapped).
2. P0-3 Equity/turn tracker (makes the class-level mechanic real).
3. P1-6 Seating-chart planning phase (high-value, leverages the seating system + lit).
4. P0-2 Real LLM backend (the headline capability; do after 1 so the judge has clear targets).
5. P3-15/16 A pass of audio + transition juice (cheap, large perceived-quality jump).
