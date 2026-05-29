extends Control
## Mission-select hub. Lists the scenarios from Game.SCENARIOS (reading each JSON for its
## title/badge), shows which badges are earned, and routes to the chosen scenario.

func _ready() -> void:
	_build()

func setup(_data: Dictionary) -> void:
	pass

func _build() -> void:
	var vp := get_viewport_rect().size

	var bg := ColorRect.new()
	bg.size = vp
	bg.color = Color(0.07, 0.09, 0.16)
	add_child(bg)

	var title := Label.new()
	title.text = "CHALK & CHANCE"
	title.position = Vector2(40, 26)
	title.add_theme_font_override("font", load("res://ui/fonts/PressStart2P-Regular.ttf"))
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.97, 0.95, 0.86))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.14))
	title.add_theme_constant_override("outline_size", 6)
	add_child(title)

	var sub := Label.new()
	sub.text = "Choose a lesson to rehearse. Earn a badge to unlock the next missions. Imported lessons are always open."
	sub.position = Vector2(42, 74)
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	add_child(sub)

	var y := 120.0
	var first: Button = null
	for id in _scenario_ids():
		var cfg := _load(id)
		var btitle: String = str(cfg.get("title", id))
		var badge: String = str(cfg.get("badge", ""))
		var earned: bool = badge != "" and GameState.has_badge(badge)
		var requires: String = str(cfg.get("requires", ""))
		var locked: bool = requires != "" and not GameState.has_badge(requires)
		var mark := ""
		if earned:
			mark = "   [DONE]"
		elif locked:
			mark = "   [LOCKED - earn the %s badge first]" % _badge_name(requires)
		var b := Button.new()
		b.text = btitle + mark
		b.position = Vector2(42, y)
		b.size = Vector2(vp.x - 84, 52)
		b.add_theme_font_size_override("font_size", 18)
		b.disabled = locked
		if not locked:
			b.pressed.connect(_choose.bind(id))
		if earned:
			b.add_theme_color_override("font_color", Color(0.55, 0.9, 0.6))
		add_child(b)
		if first == null and not locked:
			first = b
		y += 60.0

	var imp := Button.new()
	imp.text = "+  Import a lesson plan..."
	imp.position = Vector2(42, y)
	imp.size = Vector2(vp.x - 84, 50)
	imp.add_theme_font_size_override("font_size", 16)
	imp.add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
	imp.pressed.connect(_go_import)
	add_child(imp)
	y += 60.0

	var hint := Label.new()
	hint.text = "Arrow keys to move, Z / Enter to select."
	hint.position = Vector2(42, y + 8)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
	add_child(hint)

	if first != null:
		first.grab_focus()

## All scenarios found in data/scenarios/ (built-ins first in Game.SCENARIOS order, then any
## imported custom_*.json), so a lesson-plan import shows up automatically.
func _scenario_ids() -> Array:
	var found: Array = []
	for d in ["res://data/scenarios", "user://scenarios"]:
		var dir := DirAccess.open(d)
		if dir != null:
			for f in dir.get_files():
				if f.ends_with(".json") and not (f.get_basename() in found):
					found.append(f.get_basename())
	var ordered: Array = []
	for b in Game.SCENARIOS:
		if b in found:
			ordered.append(b)
			found.erase(b)
	found.sort()
	ordered.append_array(found)
	return ordered

func _load(id: String) -> Dictionary:
	var path := Game.scenario_path(id)
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(d) == TYPE_DICTIONARY:
				return d
	return {"title": id}

func _choose(id: String) -> void:
	Game.current_scenario_id = id
	var cfg := _load(id)
	var mode := str(cfg.get("mode", ""))
	if mode == "gym":
		SceneRouter.change_scene("res://scenes/encounter/GymEncounter.tscn", {"scenario": cfg})
	elif mode == "lecture":
		SceneRouter.change_scene("res://scenes/encounter/LectureScene.tscn", {"scenario": cfg})
	else:
		SceneRouter.change_scene("res://scenes/overworld/Overworld.tscn")

func _go_import() -> void:
	SceneRouter.change_scene("res://scenes/ui/ImportLesson.tscn")

func _badge_name(id: String) -> String:
	return id.capitalize()
