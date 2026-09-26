extends RefCounted
## Loads data/narrative/chapters.json and resolves speakers to name/colour/portrait.

const PATH := "res://data/narrative/chapters.json"
static var _data: Dictionary = {}

static func _load() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			_data = parsed
	return _data

static func chapter(id: String) -> Dictionary:
	var chapters: Dictionary = _load().get("chapters", {})
	return chapters.get(id, {})

static func has_intro(id: String) -> bool:
	return not (chapter(id).get("intro", []) as Array).is_empty()

static func next_chapter(n: int) -> Dictionary:
	for c in (_load().get("chapters", {}) as Dictionary).values():
		if int(c.get("chapter", 0)) == n + 1:
			return c
	return {}

## Plays the chapter outro (coach line + end card) then lands on the hub.
static func go_hub_with_outro(scenario: Dictionary, won: bool) -> void:
	var id := str(scenario.get("id", ""))
	if bool(GameState.get_setting("cinematics", true)) and not outro(id, won).is_empty():
		SceneRouter.change_scene("res://scenes/cinematic/MissionCinematic.tscn", {
			"scenario": scenario, "mode": "outro", "won": won, "next_path": "res://scenes/ui/Hub.tscn",
		})
	else:
		SceneRouter.change_scene("res://scenes/ui/Hub.tscn")

## Coach line for the debrief: outro_win or outro_retry.
static func outro(id: String, won: bool) -> Dictionary:
	return chapter(id).get("outro_win" if won else "outro_retry", {})

## -> {name, color, texture}. Cast members come from "cast"; anyone else is a persona
## id resolved against the scenario roster and assets/portraits/<id>_<mood>.png.
static func speaker(who: String, cfg: Dictionary, mood: String = "neutral") -> Dictionary:
	var cast: Dictionary = _load().get("cast", {})
	if cast.has(who):
		var c: Dictionary = cast[who]
		var base := str(c.get("portrait", ""))
		return {
			"name": str(c.get("name", "")),
			"color": Color.html(str(c.get("color", "#FFFFFF"))),
			"texture": _portrait(base, mood) if base != "" else null,
		}
	var name := who.split("_")[0].capitalize()
	for r in cfg.get("roster", []):
		if typeof(r) == TYPE_DICTIONARY and str(r.get("id", "")) == who:
			name = str(r.get("name", name))
	return {"name": name, "color": Color(0.98, 0.90, 0.70), "texture": _portrait(who, mood)}

static func _portrait(base: String, mood: String) -> Texture2D:
	for suffix in [mood, "neutral"]:
		var p := "res://assets/portraits/%s_%s.png" % [base, suffix]
		if ResourceLoader.exists(p):
			return load(p)
	return null
