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
	var screen := str(JavaScriptBridge.eval(q + ".get('dev_screen') || ''", true)).strip_edges()
	if screen == "import":
		SceneRouter.change_scene("res://scenes/ui/ImportLesson.tscn")
		return true
	if screen == "preview":
		var pcfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenarios/custom_comparing_decimals.json"))
		SceneRouter.change_scene("res://scenes/ui/PreviewScenario.tscn", {"scenario": pcfg})
		return true
	var win := str(JavaScriptBridge.eval(q + ".get('dev_win') || ''", true)).strip_edges()
	var end_lesson := str(JavaScriptBridge.eval(q + ".get('dev_end') || ''", true)) == "1"
	if win != "":
		Game.current_scenario_id = room if room != "" else "discussion_fractions"
		Game.start_lesson(Game.current_scenario_id, 120.0)
		SceneRouter.change_scene("res://scenes/encounter/Encounter.tscn", {"persona_id": win, "display_name": win.split("_")[0].capitalize()})
		# ?dev_moves=elicit,tell,extend plays those moves dev_gap s apart (1.6) before the win.
		var moves: Array = Array(str(JavaScriptBridge.eval(q + ".get('dev_moves') || ''", true)).split(",", false))
		var gap := float(str(JavaScriptBridge.eval(q + ".get('dev_gap') || '1.6'", true)))
		var t := 2.0
		for mv in moves:
			get_tree().create_timer(t).timeout.connect(func():
				var e = SceneRouter._current
				if e != null and e.has_method("_on_move"):
					if e._notice_panel != null and e._notice_panel.visible:
						e._on_notice("confused")
					e._on_move(str(mv)))
			t += gap
		get_tree().create_timer(t).timeout.connect(func():
			var enc = SceneRouter._current
			if enc != null and enc.has_method("_win"):
				enc._win("reasoning"))
		return true
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
		var dev_int := int(str(JavaScriptBridge.eval(q + ".get('dev_interrupt') || '-1'", true)))
		if dev_int >= 0:
			get_tree().create_timer(2.5).timeout.connect(func():
				var ow2 = SceneRouter._current
				if ow2 != null and ow2.has_method("_trigger_interrupt"):
					ow2._trigger_interrupt(dev_int))
		if end_lesson:
			get_tree().create_timer(2.5).timeout.connect(func():
				var ow = SceneRouter._current
				if ow != null and ow.has_method("_end_lesson"):
					ow._end_lesson())
	return true
