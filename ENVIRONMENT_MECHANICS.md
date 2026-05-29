# Environmental Factors -> Game Mechanics

Classroom factors a real teacher constantly manages, collected from the teacher's
perspective, each mapped to a concrete mechanic for Chalk & Chance. The goal is to make the
*environment itself* part of the puzzle, not just the dialogue with one student. Mechanics
reuse the four meters (Engagement / Order / Rapport / Composure) and the overworld grid we
already have. Evidence anchors point to the management literature (verify with refcheck
before any publication-facing claim).

Legend for "Status": [HAVE] already in build, [NEXT] cheap to add on current engine,
[LATER] needs new systems.

## A. Space and the teacher's body

| Factor (teacher reality) | In-game signal | Mechanic | Meters | Status | Anchor |
|---|---|---|---|---|---|
| Proximity control | Distance from each student | Standing adjacent to an off-task student is itself a least-intrusive redirect: each turn near them nudges Order up before any verbal move | Order, Composure | NEXT | Kounin proximity; Simonsen 2008 |
| Withitness (eyes everywhere) | Teacher facing + line of sight | While you face the board (writing), off-task behavior behind you rises faster; turning to scan resets it. "Withitness radius" around the teacher | Order | NEXT | Kounin 1970 (withitness) |
| Traffic flow / aisles | Desk layout blocks or opens paths | The US desk grid creates aisles; a cramped layout slows you reaching a flare-up. A pre-class layout choice trades reach vs density | Order | HAVE (layout), [LATER] editable | Classroom design lit |
| Seating chart / adjacency | Which students sit next to whom | Pre-class planning phase: drag students into seats; adjacent personas interact (Talia next to Deshawn = chatter event; anxious Mei-Lin near a calm peer = buffer) | Engagement, Order | LATER | Peer-effects; Kounin |

## B. Time and pacing

| Factor | In-game signal | Mechanic | Meters | Status | Anchor |
|---|---|---|---|---|---|
| Lesson clock / momentum | A class-period timer | Each scenario runs on a period clock; dead time and slow transitions bleed Engagement (loss of momentum) | Engagement | NEXT | Kounin (momentum, smoothness) |
| Attention curve | Time-of-period energy bar | Attention decays over the period and dips post-lunch; you must re-energize (movement, group alerting) at the right moment | Engagement | LATER | Attention/arousal research |
| Transitions | Activity-change moments | Transitions are discrete high-risk events: a clear routine + active supervision keeps Order; an unmanaged transition spikes noise | Order | NEXT | Kounin; Lemov routines |
| Pacing of questioning | Wait-Time Ring (already) | Already implemented; extend so chronic no-wait-time drains class Engagement over a period | Engagement | HAVE | Rowe 1986 |

## C. Ambient conditions

| Factor | In-game signal | Mechanic | Meters | Status | Anchor |
|---|---|---|---|---|---|
| Noise level | A class Noise meter | Off-task chatter raises Noise; crossing a threshold forces a whole-class reset (a quiet signal / chime action) or Order crashes | Order | NEXT | Management lit |
| Interruptions | Random interrupt events | Intercom announcement, a knock at the door, a late student, fire drill: timed pop-ups that cost Composure and require a quick handling choice | Composure, Order | NEXT | Real-classroom ecology |
| Physical comfort | Lighting / temperature modifier | Per-scenario modifier (stuffy afternoon room = faster attention decay; you can act: open a window decor, adjust) | Engagement | LATER | Environment-on-learning lit |

## D. Materials and resources

| Factor | In-game signal | Mechanic | Meters | Status | Anchor |
|---|---|---|---|---|---|
| Distributing materials | Handout / device tokens | A setup action before work time; fumbling distribution wastes clock and invites off-task | Engagement, Order | LATER | Routines lit |
| Tech failure | Random event | The projector dies mid-lesson: improvise (switch to board) or lose Engagement; rewards having a backup routine | Engagement, Composure | LATER | Practitioner reality |
| Cognitive load of materials | Worked-example-first (already in design) | Over-dense materials drop Engagement; representation-then-fade rewarded | Engagement | LATER | Sweller 2019 |

## E. People and climate

| Factor | In-game signal | Mechanic | Meters | Status | Anchor |
|---|---|---|---|---|---|
| Routines and procedures | A Routine buffer built early | Investing early turns in establishing routines builds an Order buffer that absorbs later disruptions; skipping it makes everything harder | Order | NEXT | Emmer & Evertson; Lemov |
| Emotional climate / a student's bad day | Hidden per-student mood (that morning) | Each student rolls a hidden mood that shifts their escalation thresholds; you must read it (professional noticing) before choosing moves | Rapport, Composure | NEXT | Jacobs 2010 (noticing) |
| Undisclosed individual needs | Hidden need flag (already in personas) | Some behavior is a hidden need, not defiance; diagnosing it before responding is the win condition (Riley archetype) | Rapport | LATER | HLP #12; McLeskey 2019 |
| Group alerting / participation spread | Equity tracker (designed) | Calling pattern across the seated grid is scored; ignoring the back rows lets Engagement decay there | Engagement | NEXT | Dallimore 2012; Kounin (group alerting) |

## F. Teacher self-regulation

| Factor | In-game signal | Mechanic | Meters | Status | Anchor |
|---|---|---|---|---|---|
| Composure under pressure | Composure (already = HP) | Already implemented; environmental events (Section C) are the main Composure drain, making self-regulation a resource you budget | Composure | HAVE | Eraut 1995 |

## Recommended build order (cheapest, highest impact first)

1. [NEXT] **Proximity + withitness** in the overworld: an off-task meter per seated student that rises while you are far / facing away, and falls when you stand adjacent or scan. This makes simply *walking the room* meaningful (and uses the seating we just built).
2. [NEXT] **Period clock + class Noise/attention bars** on the overworld HUD: the room has a live state even between encounters.
3. [NEXT] **Interrupt events**: a timed intercom/door/late-student pop-up with a 2-3 option quick choice, costing Composure.
4. [NEXT] **Routine buffer**: a short opening "establish routines" beat that sets the day's Order buffer.
5. [LATER] **Seating-chart planning phase** (drag students into the grid; adjacency effects) as a pre-class strategic layer that directly leverages the US desk layout.
6. [LATER] **Attention curve + materials/tech events** for full lesson-ecology depth.

## How this changes the loop

Today the game is: walk to a student -> dialogue encounter. With these mechanics the
overworld becomes a live classroom you must *manage continuously*: the room has noise,
attention, and off-task pressure that evolve in real time while you decide who to help,
when to address the whole class, and how to spend Composure on interruptions. The
one-on-one encounters stay the deep-skill core; the environment layer is the breadth that
makes it feel like teaching, not just a chat tree.
