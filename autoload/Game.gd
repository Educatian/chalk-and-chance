extends Node
## Tiny global holding which scenario the overworld should load. A mission-select hub will
## set this later; for now keys 1/2 in the overworld switch scenes for testing.

var current_scenario_id := "discussion_fractions"

## Persistent in-period lesson state so the period, composure, off-task and equity carry
## across the overworld<->encounter scene swaps (a lesson is one continuous period).
## Keyed by persona_id. Empty/active=false means "start a fresh period".
var lesson := {}

## Resolve a scenario id to its file: built-ins in res://, imported customs in user://.
func scenario_path(id: String) -> String:
	var r := "res://data/scenarios/%s.json" % id
	if FileAccess.file_exists(r):
		return r
	return "user://scenarios/%s.json" % id

func start_lesson(scenario_id: String, period_seconds: float) -> void:
	lesson = {
		"active": true, "scenario_id": scenario_id,
		"period_left": period_seconds, "composure": 100.0, "disruptions": 0,
		"offtask": {}, "visited": {}, "moves": [],
	}

func clear_lesson() -> void:
	lesson = {}

func lesson_active(scenario_id: String) -> bool:
	return lesson.get("active", false) and lesson.get("scenario_id", "") == scenario_id

## Record that a student was engaged (called on) and log a teaching move for scoring.
func note_visit(persona_id: String) -> void:
	if not lesson.get("active", false):
		return
	var v: Dictionary = lesson.get("visited", {})
	v[persona_id] = int(v.get(persona_id, 0)) + 1
	lesson["visited"] = v

func log_move(tag: String, wait_ok: bool, targets: bool) -> void:
	if not lesson.get("active", false):
		return
	var m: Array = lesson.get("moves", [])
	m.append({"tag": tag, "wait_ok": wait_ok, "targets": targets})
	lesson["moves"] = m

## Missions shown in the select hub, in order.
const SCENARIOS := [
	"discussion_fractions",
	"lecture_fractions",
	"group_work_fractions",
	"independent_fractions",
	"reading_main_idea",
	"science_force_motion",
	"gym_capstone",
]
