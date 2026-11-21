extends Node
## Thin bootstrapper. Loads save data, hands SceneRouter its container,
## then routes to the overworld. See GAME_CONCEPT.md section 9.1.

const UiText = preload("res://scripts/UiText.gd")

var _rotate_layer: CanvasLayer = null
var _probe_cb = null        # debug web only: JS -> Godot "press this button"
var _probe_press := ""
var _probe_t := 0.0

func _ready() -> void:
	GameState.load_game()
	GameState.apply_language()
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
	# Any dev_* run is a test: offline students, no voice, nothing sent to the hosted API.
	if str(JavaScriptBridge.eval("window.location.search", true)).contains("dev_"):
		LLMClient.use_stub = true
		TTSClient.enabled = false
		Telemetry._net = false
	_start_probe()
	var room := str(JavaScriptBridge.eval(q + ".get('dev_room') || ''", true)).strip_edges()
	var dev_lang := str(JavaScriptBridge.eval(q + ".get('dev_lang') || ''", true))
	if dev_lang in ["en", "ko"]:
		GameState.set_language(dev_lang)
	# After the language (Korean picks the Korean room): ?dev_korean=1|0 forces the room look.
	var dev_kr := str(JavaScriptBridge.eval(q + ".get('dev_korean') || ''", true))
	if dev_kr in ["0", "1"]:
		GameState.settings["korean_classroom"] = dev_kr == "1"
	var retry := str(JavaScriptBridge.eval(q + ".get('dev_retry') || ''", true)).strip_edges()
	if retry != "":
		Game.retry_focus = {"scenario_id": room, "metric": retry}
	var screen := str(JavaScriptBridge.eval(q + ".get('dev_screen') || ''", true)).strip_edges()
	if screen == "import":
		SceneRouter.change_scene("res://scenes/ui/ImportLesson.tscn")
		return true
	if screen == "preview":
		var pcfg = load("res://scripts/Content.gd").json("res://data/scenarios/custom_comparing_decimals.json")
		SceneRouter.change_scene("res://scenes/ui/PreviewScenario.tscn", {"scenario": pcfg})
		return true
	var win := str(JavaScriptBridge.eval(q + ".get('dev_win') || ''", true)).strip_edges()
	var end_lesson := str(JavaScriptBridge.eval(q + ".get('dev_end') || ''", true)) == "1"
	if win != "":
		Game.current_scenario_id = room if room != "" else "discussion_fractions"
		Game.start_lesson(Game.current_scenario_id, 120.0)
		var pdata = load("res://scripts/Content.gd").json("res://data/persona_library/%s.json" % win)
		var pname := str(pdata.get("display_name", "")) if typeof(pdata) == TYPE_DICTIONARY else ""
		SceneRouter.change_scene("res://scenes/encounter/Encounter.tscn", {"persona_id": win, "display_name": pname if pname != "" else win.split("_")[0].capitalize()})
		# ?dev_moves=elicit,tell,extend plays those moves dev_gap s apart (1.6) before the win.
		var moves: Array = Array(str(JavaScriptBridge.eval(q + ".get('dev_moves') || ''", true)).split(",", false))
		var gap := float(str(JavaScriptBridge.eval(q + ".get('dev_gap') || '1.6'", true)))
		var t := float(str(JavaScriptBridge.eval(q + ".get('dev_t0') || '2'", true)))   # first move at
		for mv in moves:
			get_tree().create_timer(t).timeout.connect(func():
				var e = SceneRouter._current
				if e != null and e.has_method("_on_move"):
					if e._notice_panel != null and e._notice_panel.visible:
						e._on_notice("confused")
					e._on_move(str(mv)))
			t += gap
		# ?dev_hold=s keeps the last move on screen longer; ?dev_bond=0..1 seeds the saved bond.
		t += float(str(JavaScriptBridge.eval(q + ".get('dev_hold') || '0'", true)))
		var bond_q := str(JavaScriptBridge.eval(q + ".get('dev_bond') || ''", true))
		if bond_q != "":
			GameState.relationships[win] = clampf(float(bond_q), 0.0, 1.0)
		get_tree().create_timer(t).timeout.connect(func():
			var enc = SceneRouter._current
			if enc != null and enc.has_method("_win"):
				enc._win("reasoning"))
		return true
	if room == "" or not FileAccess.file_exists("res://data/scenarios/%s.json" % room):
		return false
	Game.current_scenario_id = room
	var cfg = load("res://scripts/Content.gd").json("res://data/scenarios/%s.json" % room)   # as the hub would pass it
	var mode := str(cfg.get("mode", "")) if typeof(cfg) == TYPE_DICTIONARY else ""
	if mode == "gym":
		SceneRouter.change_scene("res://scenes/encounter/GymEncounter.tscn", {"scenario": cfg})
	elif mode == "lecture":
		SceneRouter.change_scene("res://scenes/encounter/LectureScene.tscn", {"scenario": cfg})
	else:
		SceneRouter.change_scene("res://scenes/overworld/Overworld.tscn")
		var quiet := str(JavaScriptBridge.eval(q + ".get('dev_quiet') || ''", true)) == "1"
		var group := str(JavaScriptBridge.eval(q + ".get('dev_group') || ''", true)) == "1"
		var dev_int := int(str(JavaScriptBridge.eval(q + ".get('dev_interrupt') || '-1'", true)))
		_when_room(func(ow):
			if quiet:
				ow._next_interrupt = 9999.0
			await get_tree().create_timer(2.0).timeout   # let the room settle on screen
			if group and not ow._npcs.is_empty():
				ow.start_encounter(ow._npcs.values()[0])
			elif dev_int >= 0:
				ow._trigger_interrupt(dev_int)
			elif end_lesson:
				ow._end_lesson())
	return true

## Debug web only: off-screen QA reads window.__cc_state (current scene + every visible
## text, source and as shown) to assert it reached the intended screen, and calls
## window.cc_press("Button text") to press a visible button by its English or shown text,
## so a script navigates the same way at any window size and in either language.
func _start_probe() -> void:
	_probe_cb = JavaScriptBridge.create_callback(func(args):
		_probe_press = str(args[0]) if args.size() > 0 else "")
	JavaScriptBridge.get_interface("window").cc_press = _probe_cb
	# SceneTree signals fire while paused too (the rotate prompt pauses the game).
	get_tree().process_frame.connect(_probe_tick)

func _probe_tick() -> void:
	var delta := get_process_delta_time()
	if _probe_press != "":
		var want := _probe_press
		_probe_press = ""
		var b := _find_button(get_tree().root, want)
		JavaScriptBridge.eval("window.__cc_pressed = %s;" % JSON.stringify(b != null))
		if b != null:
			b.pressed.emit()
	_probe_t -= delta
	if _probe_t > 0.0:
		return
	_probe_t = 0.4
	var texts: Array = []
	_collect_text(get_tree().root, texts)
	var cur = SceneRouter._current
	var st := {"scene": str(cur.scene_file_path) if cur != null else "", "rotate": _rotate_layer.visible,
		"text": "\n".join(texts).left(60000)}
	JavaScriptBridge.eval("window.__cc_state = %s;" % JSON.stringify(st))

func _shown(c: Control, t: String) -> String:
	return c.atr(t) if c.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED else t

func _collect_text(n: Node, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return
	if n is Label or n is Button:
		var t := str(n.text)
		if t != "":
			out.append(t + " || " + _shown(n, t))
	elif n is RichTextLabel:
		out.append((n as RichTextLabel).get_parsed_text())
	for ch in n.get_children():
		_collect_text(ch, out)

func _find_button(n: Node, want: String) -> BaseButton:
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return null
	if n is Button and not (n as Button).disabled:
		var t := str(n.text)
		var want_tr := TranslationServer.translate(want)
		if t == want or _shown(n, t) == want or t.begins_with(want) or t == want_tr or _shown(n, t) == want_tr:
			return n
	for ch in n.get_children():
		var f := _find_button(ch, want)
		if f != null:
			return f
	return null

## Debug hooks act once the classroom is really up (slow machines load late), not on a
## fixed timer from boot.
func _when_room(fn: Callable) -> void:
	for i in range(120):
		var ow = SceneRouter._current
		if ow != null and str(ow.scene_file_path).ends_with("Overworld.tscn") and ow.get("_player") != null:
			fn.call(ow)
			return
		await get_tree().create_timer(0.25).timeout
