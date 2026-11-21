extends Node
## Dev: headless checks for the feel pass (input helpers). Prints FEEL PASS/FAIL.
## Run: godot --headless --path . res://scenes/dev/FeelCheck.tscn
const InputFeel = preload("res://scripts/InputFeel.gd")
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
	await _check_hotkey_press()
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
