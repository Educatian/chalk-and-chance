extends Node
## Single source of truth for save data: earned badges and per-student progress.
## See GAME_CONCEPT.md section 9.2.

const SAVE_PATH := "user://save_1.json"
const SAVE_VERSION := 1

var badges: Array = []                 ## Array[String] of earned badge ids
var student_progress: Dictionary = {}  ## persona_id -> { best_understanding, resolved, attempts }
var attempts: Dictionary = {}          ## scenario_id -> times played (deliberate-practice fade)
var settings: Dictionary = {}
## Warm-demander: a per-student relationship (0..1) that PERSISTS across periods,
## not reset each lesson (Bondy & Ross; care ethic). Built by connecting to a
## student's assets and by appropriate demand; eroded by cold takeover (Tell).
var relationships: Dictionary = {}     ## persona_id -> bond 0..1
## Schon reflection-on-action: what the player chose to notice at each debrief.
var reflections: Array = []            ## Array[{scenario, prompt, choice}]

func bond(persona_id: String) -> float:
	return clampf(float(relationships.get(persona_id, 0.0)), 0.0, 1.0)

func add_bond(persona_id: String, amount: float) -> float:
	var v := clampf(bond(persona_id) + amount, 0.0, 1.0)
	relationships[persona_id] = v
	save_game()
	return v

func log_reflection(entry: Dictionary) -> void:
	reflections.append(entry)
	save_game()

func has_badge(id: String) -> bool:
	return id in badges

## Increment and return how many times this scenario has been started.
func note_attempt(id: String) -> int:
	attempts[id] = int(attempts.get(id, 0)) + 1
	save_game()
	return attempts[id]

func attempt_count(id: String) -> int:
	return int(attempts.get(id, 0))

func award_badge(id: String) -> void:
	if id not in badges:
		badges.append(id)
		save_game()

func record_student(persona_id: String, data: Dictionary) -> void:
	student_progress[persona_id] = data
	save_game()

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"badges": badges,
		"student_progress": student_progress,
		"attempts": attempts,
		"settings": settings,
		"relationships": relationships,
		"reflections": reflections,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("GameState: could not open save file for writing")
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)   # returns Variant; do not use :=
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("GameState: save file unreadable, starting fresh")
		return
	badges = parsed.get("badges", [])
	student_progress = parsed.get("student_progress", {})
	attempts = parsed.get("attempts", {})
	settings = parsed.get("settings", {})
	relationships = parsed.get("relationships", {})
	reflections = parsed.get("reflections", [])
