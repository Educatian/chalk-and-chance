extends RefCounted
## Small, shared input helpers for the feel pass: move hotkeys (1-9), "any press skips"
## detection for text reveals and turn beats, and a short directional move buffer.
## Pure logic where possible so scenes/dev/InputFeelCheck.gd can exercise it headless.

## 0-based hotkey index for a number-key press (top row or keypad), else -1.
static func hotkey_index(event: InputEvent) -> int:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return -1
	var k := (event as InputEventKey).keycode
	if k >= KEY_1 and k <= KEY_9:
		return k - KEY_1
	if k >= KEY_KP_1 and k <= KEY_KP_9:
		return k - KEY_KP_1
	return -1

## Press the hotkeyed button if it is visible and enabled. Returns true when handled.
static func press_hotkey(buttons: Array, event: InputEvent) -> bool:
	var i := hotkey_index(event)
	if i < 0 or i >= buttons.size():
		return false
	var b: BaseButton = buttons[i]
	if b == null or not is_instance_valid(b) or not b.is_visible_in_tree() or b.disabled:
		return false
	b.grab_focus()
	b.pressed.emit()
	return true

## Small hotkey number tucked into the button's top-left corner. A child label, so the
## button's own text and minimum size are untouched (layout audits stay valid).
static func add_hotkey_badge(button: Button, i: int, font_size: int, inset: Vector2 = Vector2(3, 1)) -> Label:
	if i >= 9:
		return null
	var l := Label.new()
	l.name = "HotkeyBadge"
	l.text = str(i + 1)
	l.position = inset
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(0.62, 0.70, 0.86, 0.9))
	button.add_child(l)
	return l

## True for a deliberate press from any device (not key repeat, not modifiers, not motion).
static func is_skip_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return false
		return not (k.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK, KEY_TAB])
	if event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		return m.pressed and m.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false


## Remembers the last direction tapped while a step was in flight, for a short window,
## so a quick tap during a step is not lost (input buffering, cf. "Celeste & Forgiveness").
class MoveBuffer:
	extends RefCounted
	var window_ms := 150
	var _dir := Vector2i.ZERO
	var _at_ms := -100000

	func press(dir: Vector2i, now_ms: int) -> void:
		if dir == Vector2i.ZERO:
			return
		_dir = dir
		_at_ms = now_ms

	## Returns the buffered direction if it is still fresh, then clears it.
	func take(now_ms: int) -> Vector2i:
		var d := _dir
		var fresh := now_ms - _at_ms <= window_ms
		clear()
		return d if fresh else Vector2i.ZERO

	func clear() -> void:
		_dir = Vector2i.ZERO
		_at_ms = -100000
