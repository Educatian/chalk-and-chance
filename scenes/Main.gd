extends Node
## Thin bootstrapper. Loads save data, hands SceneRouter its container,
## then routes to the overworld. See GAME_CONCEPT.md section 9.1.

const UiText = preload("res://scripts/UiText.gd")

var _rotate_layer: CanvasLayer = null

func _ready() -> void:
	GameState.load_game()
	UiText.apply_text_scale()
	# Stretch aspect "expand" can show margins around fixed 960x540 screens; keep them dark.
	RenderingServer.set_default_clear_color(Color(0.04, 0.05, 0.09))
	_build_rotate_prompt()
	get_viewport().size_changed.connect(_check_orientation)
	_check_orientation()
	SceneRouter.set_stack($SceneStack)
	if _dev_room_hook():
		return
	# Route to the learner login first if accounts are provisioned; otherwise straight
	# to the hub (offline). Login is skippable, so the game always reaches the hub.
	if Auth.configured() and not Auth.signed_in():
		SceneRouter.change_scene("res://scenes/ui/Login.tscn")
	else:
		SceneRouter.change_scene("res://scenes/ui/Hub.tscn")

## Phone held upright: the game is landscape-only, so cover it with a rotate prompt and
## pause play (the classroom clock must not run while the player cannot see the room).
func _build_rotate_prompt() -> void:
	_rotate_layer = CanvasLayer.new()
	_rotate_layer.layer = 120
	_rotate_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_rotate_layer.visible = false
	add_child(_rotate_layer)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.09, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rotate_layer.add_child(bg)
	var msg := Label.new()
	msg.text = "Turn your device sideways

Chalk & Chance plays in landscape."
	msg.set_anchors_preset(Control.PRESET_FULL_RECT)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", 64)
	msg.add_theme_color_override("font_color", Color(0.97, 0.93, 0.78))
	_rotate_layer.add_child(msg)

func is_portrait() -> bool:
	var s := get_viewport().get_visible_rect().size
	return s.y > s.x * 1.05

func _check_orientation() -> void:
	if _rotate_layer == null:
		return
	var portrait := is_portrait()
	if portrait == _rotate_layer.visible:
		return
	_rotate_layer.visible = portrait
	get_tree().paused = portrait

## Debug web builds only (never in a release export): ?dev_room=<scenario_id> opens that
## classroom directly and ?dev_korean=1 picks the Korean room, so off-screen screenshot
## runs can reach locked missions without editing save data.
func _dev_room_hook() -> bool:
	if not (OS.has_feature("web") and OS.is_debug_build() and ClassDB.class_exists("JavaScriptBridge")):
		return false
	var q := "new URLSearchParams(window.location.search)"
	var room := str(JavaScriptBridge.eval(q + ".get('dev_room') || ''", true)).strip_edges()
	if str(JavaScriptBridge.eval(q + ".get('dev_korean') || ''", true)) == "1":
		GameState.settings["korean_classroom"] = true
	if room == "" or not FileAccess.file_exists("res://data/scenarios/%s.json" % room):
		return false
	Game.current_scenario_id = room
	var cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenarios/%s.json" % room))
	var mode := str(cfg.get("mode", "")) if typeof(cfg) == TYPE_DICTIONARY else ""
	if mode == "gym":
		SceneRouter.change_scene("res://scenes/encounter/GymEncounter.tscn", {"scenario": cfg})
	elif mode == "lecture":
		SceneRouter.change_scene("res://scenes/encounter/LectureScene.tscn", {"scenario": cfg})
	else:
		SceneRouter.change_scene("res://scenes/overworld/Overworld.tscn")
	return true
