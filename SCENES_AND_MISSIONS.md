# Scenes and Missions (how to structure them)

Goal: add missions per **scene format** (lecture, group discussion, group work,
independent work, ...). Each format is a different *teaching context to rehearse*, so it
should automatically set the right seating, objectives, and which mechanics matter. The
clean way is **data-driven scenarios**: one config defines a scene; the engine reads it.

## 1. The mapping (format -> arrangement + objectives + mechanics)

Grounded in the seating literature (let the task dictate the arrangement; see
SEATING_ARRANGEMENTS.md) and the management literature.

| Scene format | Seating | Mission objectives (scored) | Mechanics emphasized | Region / Badge |
|---|---|---|---|---|
| **Lecture / Direct Instruction** | Rows | Hold attention/momentum; group alerting; wait-time on comprehension checks; minimize off-task while you talk | Withitness, pacing, attention drift, action-zone | Routine / Echo |
| **Group Discussion (Socratic)** | U-shape / horseshoe | Elicit + extend + revoice; equitable turn distribution; press for reasoning | Questioning encounters + equity tracker | Echo / Balance |
| **Group Work (collaborative)** | Clusters / pods | Circulate and monitor every group; re-engage off-task pods; prompt without taking over | Proximity across pods, per-group off-task | (new) Orchestrate |
| **Independent Work / Seatwork** | Rows | Circulate and confer 1:1; keep on-task; least-intrusive redirects | Proximity, conferring encounters | Routine |
| **Stations / Lab** | Stations | Manage transitions, materials, timing, safety | Transitions, interrupts, materials | (new) |

The same four meters and the live layer (proximity/withitness, period clock, interrupts)
stay; what changes per scene is the **arrangement**, the **objective set**, and **which
signals are scored**.

## 2. Recommended architecture: data-driven ScenarioConfig

One config object per mission. Start as a GDScript dictionary (or a `.tres` Resource /
JSON in `data/scenarios/`), e.g.:

```
{
  "id": "discussion_fractions",
  "title": "Fraction Talk (Group Discussion)",
  "format": "discussion",            # picks default arrangement + scored signals
  "arrangement": "ushape",           # rows | ushape | clusters | pairs | stations
  "period_seconds": 150,
  "roster": [ {"id":"noah_g5_fractions","seat":1}, ... ],   # seat = index into the arrangement
  "objectives": [
     {"id":"attention",  "label":"Keep class attention >= 70%", "metric":"attention_min", "target":70},
     {"id":"equity",     "label":"No student left with 0 turns", "metric":"min_turns",     "target":1},
     {"id":"elicit",     "label":"Resolve 1 misconception by eliciting", "metric":"resolved", "target":1}
  ],
  "badge": "echo"
}
```

The engine pieces (most already exist):

- **Arrangement presets**: a function `seats_for(arrangement, count)` returns the list of
  seat tiles (we already have the U-shape; add `rows`, `clusters`, `pairs`). This is the
  one new building block. Overworld stops hardcoding `SEATS` and asks the preset.
- **Overworld reads a ScenarioConfig**: build seating from `arrangement`, spawn `roster`
  into seats, set `period_seconds`, load `objectives` into the HUD/debrief. Pass the
  config via a `CurrentScenario` autoload (or SceneRouter data).
- **Objectives tracker**: generalizes today's ad-hoc attention/disruptions. Each objective
  has a metric the engine already measures (attention_min, disruptions_max, min_turns,
  resolved, wait_time_count, praise_ratio). The debrief scores each objective pass/fail and
  awards stars + the badge.
- **School hub / mission select**: a simple map or menu listing scenarios (locked/unlocked
  by badges) -> picking one loads its config. This is the "region" layer from the GDD.

## 3. Why data-driven (vs hardcoding each scene)

- Adding a scene = adding one config, not new scenes/scripts.
- Seating, objectives, and scoring stay consistent and literature-aligned.
- A future **seating-chart planning phase** (ENVIRONMENT_MECHANICS.md) drops in naturally:
  the player chooses the arrangement and the engine validates it against the format
  (choosing rows for a discussion = predictably fewer questions, per Marx 1999).

## 4. Suggested build order

1. **ScenarioConfig + arrangement presets** (`seats_for`), refactor Overworld to take a
   config. Ship 2 scenes to prove it: **Group Discussion (U-shape)** = today's scene, and a
   **Lecture (rows)** scene that scores attention/wait-time during direct instruction.
2. **Objectives tracker + debrief scoring** (stars per objective).
3. **Mission-select hub** (pick scene, unlock by badge).
4. Add **Group Work (clusters)** with per-pod monitoring, then Independent Work, Stations.

Net: missions become a content layer. Each new "scene" is a small config that snaps into
the existing room, meters, and live-management systems.
