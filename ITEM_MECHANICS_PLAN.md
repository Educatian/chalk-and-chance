# Chalk & Chance Item Mechanics Plan

Implementation status as of 2026-06-01: the P0 version is live in the Godot
project. Players receive a starter inventory, equip up to four items in Hub, see
the loadout in Preview, use item buttons during Encounter/Lecture/Gym, and earn
item rewards from badges.

## 1. Design Goal

Items should make the player think more like a teacher, not bypass the teaching problem.

In Chalk & Chance, permanent growth already comes from **Teacher Level**, **Upgrade Points**, and **Badges**. Items should therefore be **situational tools**: they help the player notice, prepare, recover, or reflect, but they should not directly solve a student's misconception.

Core rule:

> Items improve the player's ability to read and manage the classroom. They never replace Elicit, Extend, Revoice, Wait, Praise, Redirect, or Connect.

## 2. Item Role In The Game Loop

Current core loop:

1. Read the student/class state.
2. Choose a teaching move.
3. Observe the response.
4. Receive coach feedback.
5. Earn badge/XP/upgrade progress.

Item-augmented loop:

1. **Prepare:** choose up to 4 items before entering a mission.
2. **Read:** optional observation items reveal cues or reduce ambiguity.
3. **Act:** teaching moves still do the main work.
4. **Recover:** limited-use items help stabilize Composure, Order, or attention after mistakes.
5. **Reflect:** after the mission, reflection items turn logs into clearer practice goals.

## 3. System Boundaries

Items must be separated from permanent upgrades.

| System | Purpose | Persistence | Example |
|---|---|---:|---|
| Badge | Unlocks new missions | Permanent | Echo Badge unlocks reasoning missions |
| Teacher Level | Overall progression | Permanent | Level 3 teacher |
| Upgrade | Permanent ability improvement | Permanent | Wait Mastery I |
| Item | Situational teaching support | Consumable or per-mission | Cue Card, Breathing Reset |

## 4. Item Types

### A. Preparation Items

Used before a mission starts. These support planning, not in-the-moment rescue.

| Item | Player-Facing Name | Effect | Learning Concept | Risk Control |
|---|---|---|---|---|
| `student_profile_card` | Student Profile Card | Shows one student's hidden need before mission start | Knowing learners, funds of knowledge | Does not reveal the exact best move |
| `lesson_map` | Lesson Map | Highlights the mission's scored objectives and likely pressure points | Planning around objectives | No meter bonus |
| `seating_note` | Seating Note | Suggests one seating risk, such as talkative peers or withdrawn student placement | Arrangement supports pedagogy | Suggestion only |
| `question_starter_pack` | Question Starter Pack | Adds 3 optional sentence starters to Type mode | Eliciting and extending thinking | Starters must still be chosen and typed/used |

Best first implementation:

- Add `Student Profile Card`.
- Add `Lesson Map`.

These require little new UI and directly support beginner clarity.

### B. Observation Items

Used during Overworld or Encounter to read classroom state more accurately.

| Item | Player-Facing Name | Effect | Learning Concept | Risk Control |
|---|---|---|---|---|
| `noticing_lens` | Noticing Lens | Briefly highlights the most important cue in the student's line | Professional noticing: attend, interpret, decide | One use per encounter |
| `equity_snapshot` | Equity Snapshot | Shows who has not been engaged yet | Equitable participation | Does not change any meter |
| `misconception_marker` | Misconception Marker | Marks the phrase that signals the misconception | Diagnostic listening | Requires player to choose the next move |
| `wait_meter_pin` | Wait Meter Pin | Keeps the wait-time target visible for the next turn | Wait time discipline | No automatic wait credit |

Best first implementation:

- Add `Equity Snapshot` after the equity tracker exists.
- Add `Noticing Lens` for 1:1 Encounter.

### C. Recovery Items

Used after a mistake or during pressure. These stabilize the classroom but should not create a win.

| Item | Player-Facing Name | Effect | Learning Concept | Risk Control |
|---|---|---|---|---|
| `breathing_reset` | Breathing Reset | Restores a small amount of Composure | Teacher self-regulation | Cannot exceed max Composure |
| `quiet_signal` | Quiet Signal | Reduces class off-task slightly in Overworld | Routines and group alerting | Limited uses; weaker than proximity over time |
| `routine_card` | Routine Card | Adds temporary Order buffer at mission start | Clear routines | Preparation only, not panic button |
| `repair_prompt` | Repair Prompt | After a poor move, Coach Vee gives one sharper next-step hint | Error as data | No meter restoration |

Best first implementation:

- Add `Breathing Reset`.
- Add `Quiet Signal`.

These fit the current Composure/off-task mechanics.

### D. Reflection Items

Used after the mission. These convert telemetry into learning goals.

| Item | Player-Facing Name | Effect | Learning Concept | Risk Control |
|---|---|---|---|---|
| `coach_replay_token` | Coach Replay Token | Shows one replay note: "where your choice shifted the room" | Reflection-on-action | No score change |
| `evidence_tagger` | Evidence Tagger | Adds clearer labels to the debrief, such as wait, elicit, tell, redirect | Evidence-centered reflection | Only after play |
| `practice_goal_card` | Practice Goal Card | Converts weakest competency into the next mission goal | Deliberate practice | Suggestion only |

Best first implementation:

- Add `Practice Goal Card`.

This strengthens the learning arc without complicating real-time play.

## 5. Recommended Initial Item Set

The first playable item system should ship with six items:

| Item | Type | Uses | Where Used | Why First |
|---|---|---:|---|---|
| Student Profile Card | Preparation | 1 mission | Hub / Preview | Helps beginners understand student differences |
| Lesson Map | Preparation | 1 mission | Preview | Makes objectives clear |
| Noticing Lens | Observation | 1 encounter | Encounter | Supports reading cues |
| Breathing Reset | Recovery | 1 mission | Encounter / Lecture / Gym | Gives a non-punitive recovery tool |
| Quiet Signal | Recovery | 1 mission | Overworld | Uses current off-task system |
| Practice Goal Card | Reflection | 1 mission | Debrief / Hub | Connects telemetry to next practice |

## 6. Item Acquisition

Items should be earned through learning behavior, not random loot.

Acquisition rules:

| Source | Reward |
|---|---|
| First clear of a mission | 1 item linked to that mission's concept |
| Level up | choose 1 item bundle or 1 permanent upgrade point |
| Replay with improved score | 1 reflection item |
| Coach challenge completed | 1 targeted item |
| Import lesson plan | 1 Lesson Map |

No loot boxes, no random paid rewards, no currency store for the current version.

## 7. Inventory Rules

Simple rule for beginners:

- Carry limit: 2 items per mission.
- Stack limit: 3 copies per item.
- Recovery item limit: 1 recovery item per mission.
- Observation item limit: 1 per encounter.
- Preparation items must be selected before mission start.

Why:

- Forces planning.
- Prevents item spam.
- Keeps teaching moves central.

## 8. UI Placement

### Hub

Add a small `Items` button near `Upgrade`.

Hub should show:

- item inventory count
- 2 mission slots
- short item descriptions
- disabled state when an item cannot be used in the selected mission

### Preview Scenario

Before `Start`, show:

- `Mission Loadout`
- Slot 1
- Slot 2
- `Recommended: Lesson Map` if the player is new

### Encounter / Lecture / Gym

Add compact item buttons above or beside the existing action row.

Recommended layout:

- Left: teaching move buttons / Type input
- Right or top-right: small item icons with count
- Tooltip: one sentence only

Do not place item buttons inside the main move row if it risks overlap.

### Overworld

`Quiet Signal` can appear as a small icon near the HUD.

Shortcut proposal:

- Keyboard: `Q` uses the first available overworld item.
- Mouse/touch: click icon.

## 9. Data Model

Add to `GameState.gd`:

```gdscript
var inventory := {
	"student_profile_card": 1,
	"lesson_map": 1,
}
var mission_loadout := []
var item_history := []
```

Suggested item definition file:

`data/items.json`

```json
{
  "student_profile_card": {
    "name": "Student Profile Card",
    "type": "preparation",
    "max_stack": 3,
    "use_scope": "mission_preview",
    "description": "Preview one student's hidden need before the lesson."
  },
  "breathing_reset": {
    "name": "Breathing Reset",
    "type": "recovery",
    "max_stack": 3,
    "use_scope": "encounter",
    "description": "Restore a little Composure after a rough moment."
  }
}
```

## 10. Telemetry

Every item use should log:

```json
{
  "event": "item_used",
  "item_id": "breathing_reset",
  "scene": "res://scenes/encounter/Encounter.tscn",
  "scenario_id": "discussion_fractions",
  "turn": 4,
  "before": {"composure": 42},
  "after": {"composure": 57},
  "reason": "player_activated"
}
```

Also log:

- item earned
- item equipped
- item unequipped
- item unavailable
- item wasted or blocked

This matters because item use itself becomes evidence of player strategy.

## 11. Balance Rules

Starting values, with test plans:

| Mechanic | Starting Value | Test | Adjust If |
---|---:|---|---|
| Carry slots | 2 | New player can explain why they chose each item | If choices feel meaningless, reduce to 1 early game |
| Breathing Reset | +15 Composure | Player recovers but still needs correct move | If it erases mistakes, reduce to +10 |
| Quiet Signal | -12 average off-task pressure | Player uses it to buy time, not solve room | If it replaces proximity, reduce effect |
| Noticing Lens | 1 cue highlight | Player still chooses move | If it becomes answer reveal, make cue less explicit |
| Student Profile Card | 1 hidden need preview | Player plans better | If it spoils persona puzzle, show asset not win move |
| Practice Goal Card | 1 next-goal suggestion | Player selects next mission with intent | If ignored, show it in Hub goal banner |

## 12. Implementation Plan

### Phase 1: Minimal Item System

Files:

- `autoload/GameState.gd`
- `data/items.json`
- `scenes/ui/Hub.gd`
- `scenes/ui/PreviewScenario.gd`
- `autoload/Telemetry.gd`

Build:

1. Add inventory/loadout save fields.
2. Add item definitions JSON.
3. Add `Items` overlay in Hub.
4. Add `Mission Loadout` to Preview.
5. Add item equip/unequip telemetry.

Done when:

- Player can equip 2 items.
- Inventory persists after restart.
- Item choice is logged.

### Phase 2: First Functional Items

Files:

- `scenes/encounter/Encounter.gd`
- `scenes/overworld/Overworld.gd`
- `scenes/ui/PreviewScenario.gd`

Build:

1. `Lesson Map`: improves PreviewScenario objective explanation.
2. `Student Profile Card`: reveals one hidden need or asset.
3. `Breathing Reset`: restores Composure once.
4. `Quiet Signal`: reduces off-task pressure once.

Done when:

- Item effects appear in UI.
- Item use changes the relevant meter.
- Item use is logged with before/after values.

### Phase 3: Learning-Integrated Items

Files:

- `scenes/encounter/Encounter.gd`
- `scenes/encounter/LectureScene.gd`
- `scenes/encounter/GymEncounter.gd`
- `autoload/Competency.gd`

Build:

1. `Noticing Lens`: highlights cue in student dialogue.
2. `Practice Goal Card`: reads weakest competency and creates next practice prompt.
3. Add item-specific Coach Vee comments.

Done when:

- Items produce learning language, not just meter effects.
- Debrief names how item use supported a teaching concept.

## 13. 5-Component Evaluation

| Component | Evaluation |
|---|---|
| Clarity | Strong if each item has one use case and one sentence tooltip |
| Motivation | Strong because items connect mission reward to next attempt |
| Response | Strong if player chooses when to use items |
| Satisfaction | Medium until item use has sound/visual feedback |
| Fit | Strong if items are framed as teacher tools, not fantasy potions |

Main risk:

> If items directly reveal the correct move, the player stops practicing noticing and responsive teaching.

Mitigation:

- items reveal cues, not answers
- items stabilize pressure, not solve misconceptions
- items are limited per mission
- telemetry treats item use as strategy evidence

## 14. Recommended Next Step

Implement Phase 1 and the first two items:

1. `Lesson Map`
2. `Breathing Reset`

Reason:

- `Lesson Map` improves beginner clarity.
- `Breathing Reset` gives emotional recovery without weakening the core teaching puzzle.
- Both are easy to test against existing UI, Composure, and telemetry systems.

## 15. Real Classroom Alignment

Items should be named and framed as real teacher tools. The player should feel, "This is something I could actually use before, during, or after a lesson."

### A. Match Items To Real Teaching Moments

| In-Game Item | Real Classroom Equivalent | When Teachers Use It | In-Game Use |
|---|---|---|---|
| Student Profile Card | learner profile, IEP/504 note summary, interest inventory, prior observation note | before planning or conferring | previews a student's asset, need, or participation risk |
| Lesson Map | lesson plan objective map, pacing guide, success criteria | before teaching | shows what the mission is actually scoring |
| Seating Note | seating chart annotation, behavior/participation planning note | before class starts | flags adjacency or participation risks |
| Question Starter Pack | discussion stems, questioning script, talk-move card | during questioning | offers optional teacher sentence starters |
| Noticing Lens | observation protocol, coaching look-for, professional noticing checklist | during observation or coaching | highlights a cue in student speech or behavior |
| Equity Snapshot | participation tracker, cold-call tracker, tally sheet | during discussion | shows who has not yet been engaged |
| Misconception Marker | formative assessment annotation, error analysis note | during student work review | marks the phrase or behavior that signals a misconception |
| Wait Meter Pin | wait-time reminder, silent count, coaching cue | during questioning | keeps the wait-time target visible |
| Breathing Reset | self-regulation routine, pause card, reset script | after a stressful moment | restores some Composure |
| Quiet Signal | established class attention signal | during transitions or noise build-up | reduces off-task pressure slightly |
| Routine Card | posted procedure, first-then routine, entry task | start of class or transition | creates an Order buffer |
| Repair Prompt | coaching cue, "try again" sentence frame | after a poor teacher move | gives a sharper next-step hint |
| Practice Goal Card | coaching action plan, observation debrief goal | after lesson | turns telemetry into the next practice target |
| Evidence Tagger | observation rubric, video-coding tag, coaching notes | after lesson analysis | labels moves in the debrief |

### B. Match Items To The Teacher Practice Cycle

Items should sit inside a recognizable practice cycle:

1. **Plan**
   - Student Profile Card
   - Lesson Map
   - Seating Note
   - Routine Card

2. **Enact**
   - Question Starter Pack
   - Wait Meter Pin
   - Quiet Signal
   - Breathing Reset

3. **Notice**
   - Noticing Lens
   - Misconception Marker
   - Equity Snapshot

4. **Reflect**
   - Practice Goal Card
   - Evidence Tagger
   - Coach Replay Token

This keeps the item system aligned with practice-based teacher education: prepare, enact, observe evidence, reflect, retry.

### C. Scenario-Specific Matching

Different classroom formats should recommend different item loadouts.

| Scenario Format | Real Teaching Challenge | Recommended Items | Why |
|---|---|---|---|
| Lecture / Direct Instruction | pacing, attention, checking understanding | Lesson Map, Wait Meter Pin, Quiet Signal | helps chunk instruction and check before moving on |
| Group Discussion | equitable participation, reasoning, wait time | Equity Snapshot, Question Starter Pack, Noticing Lens | supports turn distribution and deeper talk moves |
| Group Work | monitoring pods, uneven participation, shared misconceptions | Noticing Lens, Misconception Marker, Quiet Signal | supports circulation and group diagnosis |
| Independent Work | conferring, redirecting, keeping students on task | Student Profile Card, Routine Card, Breathing Reset | supports differentiated response and low-intrusion recovery |
| Capstone / Gym | competing demands under pressure | Breathing Reset, Equity Snapshot, Practice Goal Card | supports orchestration without solving the puzzle |

### D. Student-Need Matching

Items should also match student profiles. This makes personas feel pedagogically meaningful rather than cosmetic.

| Student Need | Real Classroom Frame | Helpful Item | In-Game Effect |
|---|---|---|---|
| withdrawn or anxious student | warm call, wait time, psychological safety | Student Profile Card, Wait Meter Pin | helps avoid rushing or public pressure |
| English learner | processing time, representation, home-language resources | Question Starter Pack, Wait Meter Pin | encourages revoice, wait, and representation-friendly prompts |
| skeptical or disengaged student | relevance, funds of knowledge | Student Profile Card, Noticing Lens | surfaces asset/relevance cues |
| dominant participant | equitable discussion facilitation | Equity Snapshot, Routine Card | helps redistribute airtime |
| off-task student | least-intrusive redirect, proximity | Quiet Signal, Routine Card | supports non-escalating management |
| volatile/frustrated student | affect-first de-escalation | Breathing Reset, Repair Prompt | supports teacher regulation before response |
| misconception-driven student | diagnostic listening | Misconception Marker, Noticing Lens | helps identify the conceptual error |

### E. What The Game Should Teach Through Items

Each item should communicate a concrete teaching concept.

| Concept | Item Mechanic |
|---|---|
| Teaching is prepared, not improvised from zero | prep items are chosen before the mission |
| Student behavior is information | Noticing Lens and Misconception Marker reveal cues, not answers |
| Equity must be tracked because memory is biased | Equity Snapshot gives a visible distribution |
| Wait time is a discipline | Wait Meter Pin helps the player hold silence |
| Teacher emotion affects instruction | Breathing Reset restores Composure but does not solve the student issue |
| Routines prevent escalation | Routine Card gives an Order buffer before problems spike |
| Reflection converts experience into practice | Practice Goal Card turns telemetry into the next target |

### F. Naming Rule

Use professional-but-friendly names, not fantasy names.

Good:

- Student Profile Card
- Lesson Map
- Quiet Signal
- Practice Goal Card
- Noticing Lens

Avoid:

- Mind Reader
- Trust Potion
- Instant Calm
- Misconception Bomb
- Auto-Solve Card

Reason:

The game is playful, but the transfer target is real classroom judgment. Item names should help students connect the game action to field practice.

### G. Field-Use Interpretation For Players

Every item tooltip should include two lines:

1. **Game effect**
2. **Classroom meaning**

Example:

```text
Breathing Reset
Game: Restore 15 Composure once this mission.
Classroom: Pause before responding so your next move is deliberate, not reactive.
```

Example:

```text
Equity Snapshot
Game: Show who has not been engaged yet.
Classroom: Track participation because attention distribution is easy to misremember.
```

### H. Research/Teacher-Education Use

For instructor use, item choices can become discussion evidence:

| Logged Item Pattern | Possible Interpretation |
|---|---|
| Player always equips Breathing Reset | may need support with pressure and recovery |
| Player ignores Equity Snapshot in discussion | may not yet attend to participation distribution |
| Player uses Student Profile Card before each encounter | may be planning around learner differences |
| Player uses Noticing Lens after failed moves | may be learning to read evidence before acting |
| Player uses Quiet Signal repeatedly | may be over-relying on whole-class control instead of proximity or relationship |

This should appear in instructor dashboards later as "strategy evidence," not as a moral judgment.

### I. Implementation Priority For Field Alignment

Best sequence:

1. **Lesson Map**
   - real equivalent: lesson objective/success criteria
   - strongest beginner support

2. **Breathing Reset**
   - real equivalent: teacher self-regulation pause
   - supports error recovery without making a win easier

3. **Student Profile Card**
   - real equivalent: learner profile / interest inventory
   - makes differentiation visible

4. **Equity Snapshot**
   - real equivalent: participation tracker
   - strongly tied to discussion and group work

5. **Practice Goal Card**
   - real equivalent: coaching action plan
   - connects game telemetry to teacher learning
