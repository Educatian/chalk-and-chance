extends Node
## Item definitions and lightweight rules. Runtime ownership lives in GameState.

const MAX_EQUIPPED := 4

const DEFS := {
	"lesson_map": {
		"name": "Lesson Map",
		"short": "Map",
		"desc": "See the lesson's steps.",
		"icon": "res://assets/ui/items/item_lesson_map.png",
		"scopes": ["encounter", "lecture", "gym", "preview"],
	},
	"breathing_reset": {
		"name": "Breathing Reset",
		"short": "Breathe",
		"desc": "Breathe. Get composure back.",
		"icon": "res://assets/ui/items/item_breathing_reset.png",
		"scopes": ["encounter", "lecture", "gym"],
	},
	"student_profile_card": {
		"name": "Student Profile Card",
		"short": "Profile",
		"desc": "Learn what one student needs.",
		"icon": "res://assets/ui/items/item_student_profile_card.png",
		"scopes": ["encounter", "gym", "preview"],
	},
	"quiet_signal": {
		"name": "Quiet Signal",
		"short": "Signal",
		"desc": "Settle the room with a cue.",
		"icon": "res://assets/ui/items/item_quiet_signal.png",
		"scopes": ["lecture", "gym"],
	},
	"noticing_lens": {
		"name": "Noticing Lens",
		"short": "Notice",
		"desc": "Points out what to notice.",
		"icon": "res://assets/ui/items/item_noticing_lens.png",
		"scopes": ["encounter", "lecture", "gym"],
	},
	"equity_snapshot": {
		"name": "Equity Snapshot",
		"short": "Equity",
		"desc": "See who hasn't talked yet.",
		"icon": "res://assets/ui/items/item_equity_snapshot.png",
		"scopes": ["lecture", "gym", "preview"],
	},
	"wait_meter_pin": {
		"name": "Wait Meter Pin",
		"short": "Wait",
		"desc": "Makes sure you really wait.",
		"icon": "res://assets/ui/items/item_wait_meter_pin.png",
		"scopes": ["encounter", "lecture", "gym"],
	},
	"practice_goal_card": {
		"name": "Practice Goal Card",
		"short": "Goal",
		"desc": "Pick one goal for bonus XP.",
		"icon": "res://assets/ui/items/item_practice_goal_card.png",
		"scopes": ["encounter", "lecture", "gym", "preview"],
	},
}

const DEFAULT_INVENTORY := {}

const DEFAULT_LOADOUT := []

const PROFILE_LOADOUTS := {
	"base": [],
	"steady": ["breathing_reset", "quiet_signal", "wait_meter_pin", "practice_goal_card"],
	"listener": ["student_profile_card", "noticing_lens", "breathing_reset", "practice_goal_card"],
	"equity": ["equity_snapshot", "wait_meter_pin", "noticing_lens", "quiet_signal"],
}

const BADGE_REWARDS := {
	"routine": {"quiet_signal": 1, "lesson_map": 1},
	"echo": {"student_profile_card": 1, "noticing_lens": 1},
	"balance": {"equity_snapshot": 1, "wait_meter_pin": 1},
	"mirror": {"practice_goal_card": 1, "breathing_reset": 1},
	"bridge": {"student_profile_card": 1, "noticing_lens": 1},
	"insight": {"practice_goal_card": 2, "lesson_map": 1},
}


func all_ids() -> Array:
	return DEFS.keys()


func has_item(id: String) -> bool:
	return DEFS.has(id)


func def(id: String) -> Dictionary:
	return DEFS.get(id, {})


func name_for(id: String) -> String:
	return tr(str(def(id).get("name", id.capitalize())))


func short_name_for(id: String) -> String:
	return tr(str(def(id).get("short", def(id).get("name", id.capitalize()))))


func icon_for(id: String) -> String:
	return str(def(id).get("icon", ""))


func desc_for(id: String) -> String:
	return str(def(id).get("desc", ""))


func usable_in(id: String, scope: String) -> bool:
	var scopes: Array = def(id).get("scopes", [])
	return scope in scopes
