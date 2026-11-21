extends Node
## Dev: headless checks for the feel pass (input helpers, turn beat, honest feedback).
## Prints FEEL PASS/FAIL.
## Run: godot --headless --path . res://scenes/dev/FeelCheck.tscn
const InputFeel = preload("res://scripts/InputFeel.gd")
const TurnBeat = preload("res://scripts/TurnBeat.gd")
const CompletionFx = preload("res://scenes/encounter/CompletionFx.gd")
const UiText = preload("res://scripts/UiText.gd")
var fails := 0

func _ok(label: String, cond: bool) -> void:
	print("FEEL | [%s] %s" % ["OK " if cond else "XX", label])
	if not cond:
		fails += 1

func _key(code: Key, pressed := true, echo := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = pressed
	e.echo = echo
	return e

func _ready() -> void:
	_check_hotkeys()
	_check_skip()
	_check_move_buffer()
	_check_grid_path()
	await _check_hotkey_press()
	_check_outcomes()
	_check_beat_order()
	await _check_juice()
	_check_text_scale()
	print("FEEL %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	get_tree().quit(0 if fails == 0 else 1)

func _check_hotkeys() -> void:
	_ok("1 maps to move 0", InputFeel.hotkey_index(_key(KEY_1)) == 0)
	_ok("8 maps to move 7", InputFeel.hotkey_index(_key(KEY_8)) == 7)
	_ok("keypad 3 maps to move 2", InputFeel.hotkey_index(_key(KEY_KP_3)) == 2)
	_ok("0 is not a move", InputFeel.hotkey_index(_key(KEY_0)) == -1)
	_ok("key release is ignored", InputFeel.hotkey_index(_key(KEY_2, false)) == -1)
	_ok("key repeat is ignored", InputFeel.hotkey_index(_key(KEY_2, true, true)) == -1)

func _check_skip() -> void:
	_ok("Enter skips", InputFeel.is_skip_press(_key(KEY_ENTER)))
	_ok("Shift alone does not skip", not InputFeel.is_skip_press(_key(KEY_SHIFT)))
	_ok("key repeat does not skip", not InputFeel.is_skip_press(_key(KEY_SPACE, true, true)))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_ok("left click skips", InputFeel.is_skip_press(click))
	var pad := InputEventJoypadButton.new()
	pad.pressed = true
	_ok("pad button skips", InputFeel.is_skip_press(pad))
	_ok("mouse motion does not skip", not InputFeel.is_skip_press(InputEventMouseMotion.new()))

func _check_move_buffer() -> void:
	var b := InputFeel.MoveBuffer.new()
	b.window_ms = 150
	_ok("empty buffer yields nothing", b.take(0) == Vector2i.ZERO)
	b.press(Vector2i(1, 0), 1000)
	_ok("fresh tap is replayed", b.take(1100) == Vector2i(1, 0))
	_ok("a tap is replayed only once", b.take(1101) == Vector2i.ZERO)
	b.press(Vector2i(0, 1), 1000)
	_ok("stale tap is dropped", b.take(1200) == Vector2i.ZERO)
	b.press(Vector2i(0, 1), 1000)
	b.press(Vector2i(-1, 0), 1050)
	_ok("latest tap wins", b.take(1100) == Vector2i(-1, 0))
	b.press(Vector2i(0, -1), 1000)
	b.clear()
	_ok("clear empties the buffer", b.take(1001) == Vector2i.ZERO)

func _check_hotkey_press() -> void:
	var hits: Array = []
	var buttons: Array = []
	for i in 3:
		var btn := Button.new()
		btn.pressed.connect(func(): hits.append(i))
		add_child(btn)
		buttons.append(btn)
	await get_tree().process_frame
	_ok("hotkey 2 presses the second button", InputFeel.press_hotkey(buttons, _key(KEY_2)) and hits == [1])
	buttons[2].disabled = true
	_ok("disabled button is not pressed", not InputFeel.press_hotkey(buttons, _key(KEY_3)) and hits == [1])
	buttons[0].visible = false
	_ok("hidden button is not pressed", not InputFeel.press_hotkey(buttons, _key(KEY_1)) and hits == [1])
	_ok("out-of-range hotkey is ignored", not InputFeel.press_hotkey(buttons, _key(KEY_9)))
	for btn in buttons:
		btn.queue_free()

func _check_outcomes() -> void:
	_ok("on-target move reads as right", TurnBeat.outcome(true, "advance") == TurnBeat.RIGHT)
	_ok("'right idea, too early' reads as early, not wrong", TurnBeat.outcome(false, "early") == TurnBeat.EARLY)
	_ok("a miss reads as wrong", TurnBeat.outcome(false, "miss") == TurnBeat.WRONG)
	var cues := [TurnBeat.cue(TurnBeat.RIGHT), TurnBeat.cue(TurnBeat.EARLY), TurnBeat.cue(TurnBeat.WRONG)]
	_ok("right / early / wrong each have their own cue", cues[0] != cues[1] and cues[1] != cues[2] and cues[0] != cues[2])
	_ok("early and wrong have different labels", TurnBeat.label(TurnBeat.EARLY) != TurnBeat.label(TurnBeat.WRONG))
	for c in cues + ["commit", "win", "bump", "turn_neutral"]:
		_ok("Sfx has cue '%s'" % c, Sfx._streams.has(c))
	_ok("rank D gets no confetti", CompletionFx.confetti_count("D") == 0)
	_ok("rank B gets less confetti than S", CompletionFx.confetti_count("B") < CompletionFx.confetti_count("S"))

func _check_beat_order() -> void:
	var log: Array = []
	var beat := TurnBeat.new()
	beat.at(0.42, func(): log.append("coach"))
	beat.at(0.12, func(): log.append("cue"))
	beat.at(0.75, func(): log.append("end"))
	beat.advance(0.05)
	_ok("nothing fires before its time", log.is_empty())
	beat.advance(0.10)
	_ok("cue fires first, alone", log == ["cue"])
	beat.advance(0.30)
	_ok("coach line follows the cue", log == ["cue", "coach"])
	_ok("beat not done before the end step", not beat.is_done())
	beat.finish()
	_ok("finish runs the rest in order, once", log == ["cue", "coach", "end"] and beat.is_done())
	beat.finish()
	_ok("finishing twice does not repeat steps", log.size() == 3)

func _check_juice() -> void:
	var owner := Node.new()
	add_child(owner)
	var hits: Array = []
	var beat := TurnBeat.new()
	beat.at(5.0, func(): hits.append(1))
	Juice.play_beat(owner, beat)
	_ok("Juice tracks a running beat", Juice.has_beat(owner))
	_ok("skip_beats reports it skipped", Juice.skip_beats(owner))
	_ok("skipping runs the pending step", hits == [1] and not Juice.has_beat(owner))
	var freed := TurnBeat.new()
	freed.at(0.01, func(): hits.append(2))
	Juice.play_beat(owner, freed)
	owner.free()
	await get_tree().process_frame
	await get_tree().process_frame
	_ok("a freed owner's beat is dropped, never run", hits == [1])
	var bar := ColorRect.new()
	add_child(bar)
	bar.size = Vector2(10, 4)
	var was: bool = bool(GameState.get_setting("reduced_motion", false))
	GameState.settings["reduced_motion"] = true
	Juice.bar_to(bar, Vector2(80, 4))
	_ok("reduced motion: bars snap to their value", bar.size == Vector2(80, 4))
	GameState.settings["reduced_motion"] = false
	Juice.bar_to(bar, Vector2(20, 4))
	_ok("with motion: bars ease (not instant)", bar.size != Vector2(20, 4))
	GameState.settings["reduced_motion"] = was
	bar.queue_free()

func _check_text_scale() -> void:
	var theme := ThemeDB.get_project_theme()
	var was: bool = bool(GameState.get_setting("large_text", false))
	GameState.settings["large_text"] = false
	UiText.apply_text_scale()
	var normal := theme.get_font_size(&"font_size", UiText.HUD)
	GameState.settings["large_text"] = true
	UiText.apply_text_scale()
	var large := theme.get_font_size(&"font_size", UiText.HUD)
	_ok("HUD text style exists in the theme", normal == int(UiText.BASE_SIZES[UiText.HUD]))
	_ok("Large text grows every themed label", large > normal)
	GameState.settings["large_text"] = was
	UiText.apply_text_scale()

func _check_grid_path() -> void:
	# 5x3 room with a wall at (2,0) and (2,1): the path must go around through row 2.
	var walls := {Vector2i(2, 0): true, Vector2i(2, 1): true}
	var walkable := func(t: Vector2i) -> bool:
		return t.x >= 0 and t.y >= 0 and t.x < 5 and t.y < 3 and not walls.has(t)
	var p := InputFeel.grid_path(Vector2i(0, 0), Vector2i(4, 0), walkable)
	_ok("path goes around the wall", p.size() == 9 and not p.has(Vector2i(2, 0)) and p[0] == Vector2i(0, 0) and p[-1] == Vector2i(4, 0))
	var steps_ok := true
	for i in range(1, p.size()):
		var d: Vector2i = p[i] - p[i - 1]
		steps_ok = steps_ok and (absi(d.x) + absi(d.y) == 1)
	_ok("path moves one tile at a time", steps_ok)
	_ok("blocked goal gives no path", InputFeel.grid_path(Vector2i(0, 0), Vector2i(2, 0), walkable).is_empty())
	walls[Vector2i(2, 2)] = true
	_ok("walled-off goal gives no path", InputFeel.grid_path(Vector2i(0, 0), Vector2i(4, 0), walkable).is_empty())
	_ok("start == goal is a zero-step path", InputFeel.grid_path(Vector2i(1, 1), Vector2i(1, 1), walkable) == [Vector2i(1, 1)])
