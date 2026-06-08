extends Node
## Single source of truth for save data: earned badges and per-student progress.
## See GAME_CONCEPT.md section 9.2.

const SAVE_PATH := "user://save_1.json"
const SAVE_VERSION := 1
const DEFAULT_SETTINGS := {
	"audio_enabled": true,
	"large_text": false,
	"reduced_motion": false,
	"text_reveal": "typewriter",
}
const DEFAULT_UPGRADES := {
	"steady_presence": 0,
	"wait_mastery": 0,
	"relationship_sense": 0,
}
const TEACHER_PROFILE_ORDER := ["base", "steady", "listener", "equity"]
const TEACHER_PROFILE_DEFS := {
	"base": {
		"name": "Base",
		"short": "Base",
		"desc": "Baseline rehearsal with no profile bonus.",
		"composure_bonus": 0.0,
		"wait_reduction_ms": 0,
		"relationship_bonus": 0.0,
	},
	"steady": {
		"name": "Steady Lead",
		"short": "Steady",
		"desc": "Safer recovery and order tools.",
		"composure_bonus": 10.0,
		"wait_reduction_ms": 0,
		"relationship_bonus": 0.0,
	},
	"listener": {
		"name": "Deep Listener",
		"short": "Listen",
		"desc": "Starts with profile and noticing tools.",
		"composure_bonus": 0.0,
		"wait_reduction_ms": 0,
		"relationship_bonus": 0.05,
	},
	"equity": {
		"name": "Equity Scout",
		"short": "Equity",
		"desc": "Defaults toward airtime and wait-time control.",
		"composure_bonus": 0.0,
		"wait_reduction_ms": 300,
		"relationship_bonus": 0.0,
	},
}
const UPGRADE_DEFS := {
	"steady_presence": {
		"name": "Steady Presence",
		"desc": "+10 max Composure each rank.",
		"max": 3,
	},
	"wait_mastery": {
		"name": "Wait Mastery",
		"desc": "Wait-time readiness is 0.25s faster each rank.",
		"max": 3,
	},
	"relationship_sense": {
		"name": "Relationship Sense",
		"desc": "Start encounters with more rapport and engagement.",
		"max": 3,
	},
}

var badges: Array = []                 ## Array[String] of earned badge ids
var student_progress: Dictionary = {}  ## persona_id -> { best_understanding, resolved, attempts }
var attempts: Dictionary = {}          ## scenario_id -> times played (deliberate-practice fade)
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var teacher_xp := 0
var teacher_level := 1
var upgrade_points := 0
var upgrades: Dictionary = DEFAULT_UPGRADES.duplicate()
var inventory: Dictionary = {}         ## item_id -> count
var equipped_items: Array = []         ## Array[String], up to Items.MAX_EQUIPPED
var item_history: Array = []           ## item economy/use audit trail
var item_cooldowns: Dictionary = {}    ## item_id -> unix/time marker, reserved for future tuning
var teacher_profile_id := "base"
var leaderboard_records: Array = []    ## local run records, sorted by score desc
## Warm-demander: a per-student relationship (0..1) that PERSISTS across periods,
## not reset each lesson (Bondy & Ross; care ethic). Built by connecting to a
## student's assets and by appropriate demand; eroded by cold takeover (Tell).
var relationships: Dictionary = {}     ## persona_id -> bond 0..1
## Schon reflection-on-action: what the player chose to notice at each debrief.
var reflections: Array = []            ## Array[{scenario, prompt, choice}]
var course_baseline_classes: Array = [] ## class codes whose local starter state was normalized

func _ready() -> void:
	ensure_item_defaults()

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

func get_setting(key: String, fallback = null):
	if fallback == null:
		fallback = DEFAULT_SETTINGS.get(key, null)
	return settings.get(key, fallback)

func set_setting(key: String, value) -> void:
	settings[key] = value
	save_game()

func ui_font_delta() -> int:
	return 2 if bool(get_setting("large_text", false)) else 0

func ensure_item_defaults() -> void:
	for id in Items.DEFAULT_INVENTORY.keys():
		if not inventory.has(id):
			inventory[id] = int(Items.DEFAULT_INVENTORY[id])
	if equipped_items.is_empty():
		for id in _default_loadout_for_profile():
			if item_count(id) > 0 and Items.has_item(id):
				equipped_items.append(id)
	equipped_items = equipped_items.filter(func(id): return Items.has_item(str(id)) and item_count(str(id)) > 0)
	while equipped_items.size() > Items.MAX_EQUIPPED:
		equipped_items.pop_back()

func _default_loadout_for_profile() -> Array:
	var profile_loadout: Array = Items.PROFILE_LOADOUTS.get(teacher_profile_id, Items.DEFAULT_LOADOUT)
	return profile_loadout

func teacher_profile() -> Dictionary:
	return TEACHER_PROFILE_DEFS.get(teacher_profile_id, TEACHER_PROFILE_DEFS["base"])

func teacher_profile_label() -> String:
	var def: Dictionary = teacher_profile()
	return "%s: %s" % [str(def.get("name", "Steady Lead")), str(def.get("desc", ""))]

func teacher_profile_mechanic_text() -> String:
	var def: Dictionary = teacher_profile()
	var parts: Array = []
	var comp := int(round(float(def.get("composure_bonus", 0.0))))
	var wait := int(def.get("wait_reduction_ms", 0))
	var rel := int(round(float(def.get("relationship_bonus", 0.0)) * 100.0))
	if comp > 0:
		parts.append("+%d Composure" % comp)
	if wait > 0:
		parts.append("Wait window -%.1fs" % (float(wait) / 1000.0))
	if rel > 0:
		parts.append("+%d%% starting rapport" % rel)
	if parts.is_empty():
		return "Baseline: no bonus, no starter items"
	return " | ".join(parts)

func set_teacher_profile(id: String, apply_default_loadout: bool = true) -> void:
	if not TEACHER_PROFILE_DEFS.has(id):
		id = "base"
	teacher_profile_id = id
	if apply_default_loadout:
		equipped_items = []
		for item_id in _default_loadout_for_profile():
			if Items.has_item(str(item_id)) and item_count(str(item_id)) > 0:
				equipped_items.append(str(item_id))
	save_game()

func cycle_teacher_profile() -> void:
	var idx := TEACHER_PROFILE_ORDER.find(teacher_profile_id)
	if idx < 0:
		idx = 0
	set_teacher_profile(str(TEACHER_PROFILE_ORDER[(idx + 1) % TEACHER_PROFILE_ORDER.size()]), true)

func item_count(id: String) -> int:
	return maxi(0, int(inventory.get(id, 0)))

func equipped_item_ids() -> Array:
	ensure_item_defaults()
	return equipped_items.duplicate()

func can_equip_item(id: String) -> bool:
	ensure_item_defaults()
	if not Items.has_item(id) or item_count(id) <= 0:
		return false
	if id in equipped_items:
		return true
	return equipped_items.size() < Items.MAX_EQUIPPED

func equip_item(id: String) -> bool:
	ensure_item_defaults()
	if not can_equip_item(id):
		return false
	if id not in equipped_items:
		equipped_items.append(id)
		item_history.append({"event": "item_equipped", "item_id": id, "unix": Time.get_unix_time_from_system()})
		save_game()
	return true

func unequip_item(id: String) -> bool:
	ensure_item_defaults()
	if id not in equipped_items:
		return false
	equipped_items.erase(id)
	item_history.append({"event": "item_unequipped", "item_id": id, "unix": Time.get_unix_time_from_system()})
	save_game()
	return true

func can_use_item(id: String, scope: String) -> bool:
	ensure_item_defaults()
	return id in equipped_items and item_count(id) > 0 and Items.usable_in(id, scope)

func use_item(id: String, scope: String, context: Dictionary = {}) -> Dictionary:
	ensure_item_defaults()
	if not can_use_item(id, scope):
		var blocked := {"ok": false, "item_id": id, "scope": scope, "reason": "unavailable"}
		item_history.append({"event": "item_blocked", "item_id": id, "scope": scope, "context": context, "unix": Time.get_unix_time_from_system()})
		save_game()
		return blocked
	inventory[id] = item_count(id) - 1
	if item_count(id) <= 0:
		equipped_items.erase(id)
	var used := {"ok": true, "item_id": id, "scope": scope, "remaining": item_count(id)}
	item_history.append({"event": "item_used", "item_id": id, "scope": scope, "context": context, "remaining": item_count(id), "unix": Time.get_unix_time_from_system()})
	save_game()
	return used

func award_item(id: String, amount: int = 1, reason: String = "") -> void:
	if not Items.has_item(id) or amount <= 0:
		return
	inventory[id] = item_count(id) + amount
	item_history.append({"event": "item_awarded", "item_id": id, "amount": amount, "reason": reason, "unix": Time.get_unix_time_from_system()})
	ensure_item_defaults()
	save_game()

func award_items(items: Dictionary, reason: String = "") -> Dictionary:
	var awarded := {}
	for id in items.keys():
		var amt := int(items[id])
		if Items.has_item(str(id)) and amt > 0:
			inventory[str(id)] = item_count(str(id)) + amt
			awarded[str(id)] = int(awarded.get(str(id), 0)) + amt
			item_history.append({"event": "item_awarded", "item_id": str(id), "amount": amt, "reason": reason, "unix": Time.get_unix_time_from_system()})
	ensure_item_defaults()
	save_game()
	return awarded

func xp_for_level(level: int) -> int:
	var steps := maxi(level - 1, 0)
	return 120 * steps + 20 * steps * maxi(steps - 1, 0)

func xp_to_next_level() -> int:
	return maxi(0, xp_for_level(teacher_level + 1) - teacher_xp)

func level_progress() -> float:
	var low := xp_for_level(teacher_level)
	var high := xp_for_level(teacher_level + 1)
	return clampf(float(teacher_xp - low) / float(maxi(1, high - low)), 0.0, 1.0)

func add_teacher_xp(amount: int, reason: String = "", save_now: bool = true) -> Dictionary:
	var before := teacher_level
	teacher_xp = maxi(0, teacher_xp + maxi(0, amount))
	while teacher_xp >= xp_for_level(teacher_level + 1):
		teacher_level += 1
		upgrade_points += 1
	var info := {
		"xp_gained": maxi(0, amount),
		"reason": reason,
		"level_before": before,
		"level_after": teacher_level,
		"level_up": teacher_level > before,
		"upgrade_points": upgrade_points,
	}
	if save_now:
		save_game()
	return info

func apply_course_baseline(class_code: String) -> void:
	if class_code != "UA-CAT531-SUMMER26":
		return
	if class_code in course_baseline_classes:
		return
	teacher_profile_id = "base"
	inventory = {}
	equipped_items = []
	item_cooldowns = {}
	course_baseline_classes.append(class_code)
	item_history.append({"event": "course_baseline_applied", "class_code": class_code, "unix": Time.get_unix_time_from_system()})
	save_game()

func record_leaderboard(entry: Dictionary) -> Dictionary:
	var score := maxi(0, int(entry.get("score", 0)))
	var report := _coach_report_fields()
	var rec := {
		"scenario_id": str(entry.get("scenario_id", "")),
		"title": str(entry.get("title", "Lesson")),
		"mode": str(entry.get("mode", "Practice")),
		"score": score,
		"rank": _rank_for_score(score),
		"level": teacher_level,
		"xp": teacher_xp,
		"badge": str(entry.get("badge", "")),
		"detail": str(entry.get("detail", "")),
		"level_up": bool(entry.get("level_up", false)),
		"profile_id": teacher_profile_id,
		"profile": str(teacher_profile().get("short", "Base")),
		"coach_focus": str(report.get("focus", "")),
		"coach_next": str(report.get("next", "")),
		"coach_evidence": int(report.get("evidence", 0)),
		"adaptive_level": str(report.get("adaptive_level", "Adaptive: standard start")),
		"evidence_trace": str(entry.get("trace", "")),
		"evidence_trace_steps": entry.get("trace_steps", []),
		"unix": Time.get_unix_time_from_system(),
	}
	leaderboard_records.append(rec)
	leaderboard_records.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
	while leaderboard_records.size() > 30:
		leaderboard_records.pop_back()
	save_game()
	return rec

func _coach_report_fields() -> Dictionary:
	var rows := Competency.summary()
	var weakest := {}
	for r in rows:
		if int(r.get("n", 0)) <= 0:
			continue
		if weakest.is_empty() or float(r.get("prob", 0.5)) < float(weakest.get("prob", 0.5)):
			weakest = r
	var difficulty := Game.adaptive_difficulty(Competency.SKILLS)
	if weakest.is_empty():
		return {
			"focus": "Collect first evidence",
			"next": "Clear one mission to produce a coachable trace.",
			"evidence": 0,
			"adaptive_level": Game.adaptive_difficulty_label(difficulty),
		}
	return {
		"focus": "%s %d%%" % [str(weakest.get("label", weakest.get("skill", "Focus"))), int(round(float(weakest.get("prob", 0.5)) * 100.0))],
		"next": Game.evidence_practice_target(false),
		"evidence": int(weakest.get("n", 0)),
		"adaptive_level": Game.adaptive_difficulty_label(difficulty),
	}

func leaderboard_top(limit: int = 8) -> Array:
	var rows := leaderboard_records.duplicate()
	rows.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
	return rows.slice(0, maxi(0, limit))

func _rank_for_score(score: int) -> String:
	if score >= 260:
		return "S"
	if score >= 210:
		return "A"
	if score >= 165:
		return "B"
	if score >= 120:
		return "C"
	return "D"

func badge_xp(_badge_id: String) -> int:
	return 120

func upgrade_rank(id: String) -> int:
	return int(upgrades.get(id, 0))

func spend_upgrade(id: String) -> bool:
	if upgrade_points <= 0 or not UPGRADE_DEFS.has(id):
		return false
	var max_rank := int(UPGRADE_DEFS[id].get("max", 1))
	if upgrade_rank(id) >= max_rank:
		return false
	upgrades[id] = upgrade_rank(id) + 1
	upgrade_points -= 1
	save_game()
	return true

func max_composure() -> float:
	return 100.0 + float(teacher_profile().get("composure_bonus", 0.0)) + 10.0 * float(upgrade_rank("steady_presence"))

func wait_threshold_ms() -> int:
	return maxi(2000, 3000 - int(teacher_profile().get("wait_reduction_ms", 0)) - 250 * upgrade_rank("wait_mastery"))

func effective_wait_ms(raw_wait_ms: int) -> int:
	return raw_wait_ms + 250 * upgrade_rank("wait_mastery")

func relationship_start_bonus() -> float:
	return float(teacher_profile().get("relationship_bonus", 0.0)) + 0.05 * float(upgrade_rank("relationship_sense"))

func has_badge(id: String) -> bool:
	return id in badges

## Increment and return how many times this scenario has been started.
func note_attempt(id: String) -> int:
	attempts[id] = int(attempts.get(id, 0)) + 1
	save_game()
	return attempts[id]

func attempt_count(id: String) -> int:
	return int(attempts.get(id, 0))

func award_badge(id: String) -> Dictionary:
	var reward := {
		"badge_new": false,
		"badge": id,
		"xp_gained": 0,
		"level_up": false,
		"level_before": teacher_level,
		"level_after": teacher_level,
		"upgrade_points": upgrade_points,
	}
	if id not in badges:
		badges.append(id)
		var xp_info := add_teacher_xp(badge_xp(id), "badge:%s" % id, false)
		for k in xp_info.keys():
			reward[k] = xp_info[k]
		reward["badge_new"] = true
		reward["items_awarded"] = award_items(Items.BADGE_REWARDS.get(id, {}), "badge:%s" % id)
		save_game()
	return reward

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
		"teacher_xp": teacher_xp,
		"teacher_level": teacher_level,
		"upgrade_points": upgrade_points,
		"upgrades": upgrades,
		"inventory": inventory,
		"equipped_items": equipped_items,
		"item_history": item_history,
		"item_cooldowns": item_cooldowns,
		"teacher_profile_id": teacher_profile_id,
		"leaderboard_records": leaderboard_records,
		"relationships": relationships,
		"reflections": reflections,
		"course_baseline_classes": course_baseline_classes,
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
	settings = DEFAULT_SETTINGS.duplicate()
	var loaded_settings = parsed.get("settings", {})
	if typeof(loaded_settings) == TYPE_DICTIONARY:
		for k in loaded_settings.keys():
			settings[k] = loaded_settings[k]
	teacher_xp = int(parsed.get("teacher_xp", 0))
	teacher_level = maxi(1, int(parsed.get("teacher_level", 1)))
	upgrade_points = maxi(0, int(parsed.get("upgrade_points", 0)))
	leaderboard_records = parsed.get("leaderboard_records", [])
	upgrades = DEFAULT_UPGRADES.duplicate()
	var loaded_upgrades = parsed.get("upgrades", {})
	if typeof(loaded_upgrades) == TYPE_DICTIONARY:
		for k in loaded_upgrades.keys():
			if DEFAULT_UPGRADES.has(k):
				upgrades[k] = clampi(int(loaded_upgrades[k]), 0, int(UPGRADE_DEFS[k].get("max", 1)))
	inventory = {}
	var loaded_inventory = parsed.get("inventory", {})
	if typeof(loaded_inventory) == TYPE_DICTIONARY:
		for k in loaded_inventory.keys():
			if Items.has_item(str(k)):
				inventory[str(k)] = maxi(0, int(loaded_inventory[k]))
	equipped_items = []
	var loaded_equipped = parsed.get("equipped_items", [])
	if typeof(loaded_equipped) == TYPE_ARRAY:
		for id in loaded_equipped:
			if Items.has_item(str(id)) and str(id) not in equipped_items:
				equipped_items.append(str(id))
	item_history = parsed.get("item_history", [])
	item_cooldowns = parsed.get("item_cooldowns", {})
	teacher_profile_id = str(parsed.get("teacher_profile_id", "base"))
	if not TEACHER_PROFILE_DEFS.has(teacher_profile_id):
		teacher_profile_id = "base"
	ensure_item_defaults()
	relationships = parsed.get("relationships", {})
	reflections = parsed.get("reflections", [])
	course_baseline_classes = parsed.get("course_baseline_classes", [])
