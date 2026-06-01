extends Node
## Runtime telemetry contract test.
## Verifies that local JSONL logging records core event types and required fields.

var _failures: Array[String] = []

func _ready() -> void:
	TTSClient.enabled = false
	if Telemetry._f == null:
		_fail("Telemetry file was not opened")
		_finish()
		return

	Telemetry.capture_raw_input = true
	Telemetry.capture_mouse_motion = true

	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_SPACE
	key.physical_keycode = KEY_SPACE
	Telemetry._input(key)

	var mouse := InputEventMouseButton.new()
	mouse.pressed = true
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = Vector2(24, 36)
	Telemetry._input(mouse)

	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.index = 0
	touch.position = Vector2(48, 72)
	Telemetry._input(touch)

	var joy := InputEventJoypadButton.new()
	joy.pressed = true
	joy.button_index = JOY_BUTTON_A
	Telemetry._input(joy)

	Telemetry.log_event({"event": "telemetry_probe", "probe": "generic"})
	Telemetry.log_player_movement("probe_step", {"tile": {"x": 1, "y": 2}, "from": {"x": 0, "y": 2}})
	Telemetry.log_event({
		"event": "item_used",
		"item_id": "noticing_lens",
		"scope": "telemetry_test",
		"remaining": 1,
	})

	var button := Button.new()
	button.text = "Probe Button"
	add_child(button)
	await get_tree().create_timer(0.55).timeout
	button.pressed.emit()

	Telemetry.log_turn({
		"scenario_id": "telemetry_test",
		"persona_id": "probe_student",
		"turn": 1,
		"move": {
			"tag": "elicit",
			"wait_ms": 3100,
			"input_mode": "menu",
			"text": "What makes you think that?",
		},
		"judge": {"tags": ["elicit"], "targets": true, "wait_ok": true},
		"deltas": {"understanding": 0.12, "rapport": 2},
		"meters": {"understanding": 0.4, "rapport": 64},
		"emotion_shown": "thinking",
		"student_text": "I am comparing the parts.",
		"coach_tip": "Probe captured.",
	})

	await get_tree().process_frame
	_verify_file()
	_finish()

func _verify_file() -> void:
	var f := FileAccess.open(Telemetry._path, FileAccess.READ)
	if f == null:
		_fail("Could not reopen telemetry file: %s" % Telemetry._path)
		return

	var events: Dictionary = {}
	var line_count := 0
	var turn_event: Dictionary = {}
	var ui_event: Dictionary = {}
	var item_event: Dictionary = {}

	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "":
			continue
		line_count += 1
		var parsed = JSON.parse_string(line)
		if typeof(parsed) != TYPE_DICTIONARY:
			_fail("Invalid JSONL line %d" % line_count)
			continue
		var e: Dictionary = parsed
		for field in ["event", "session_id", "t_ms", "unix"]:
			if not e.has(field):
				_fail("Missing field '%s' in line %d" % [field, line_count])
		var name := str(e.get("event", ""))
		events[name] = true
		if name == "turn":
			turn_event = e
		elif name == "ui_button_pressed":
			ui_event = e
		elif name == "item_used":
			item_event = e
	f.close()

	for required in [
		"session_start",
		"input_key",
		"input_mouse_button",
		"input_touch",
		"input_joy_button",
		"telemetry_probe",
		"player_movement",
		"item_used",
		"ui_button_pressed",
		"turn",
	]:
		if not events.has(required):
			_fail("Missing event: %s" % required)

	if turn_event.is_empty():
		_fail("Missing turn payload")
	else:
		_expect_eq(turn_event.get("construct_id", ""), "elicit_reasoning", "turn construct_id")
		if not turn_event.has("xapi"):
			_fail("Turn event missing xapi envelope")
		else:
			var xapi: Dictionary = turn_event["xapi"]
			_expect_eq(str(xapi.get("verb", "")), "elicited", "xAPI verb")
			var result: Dictionary = xapi.get("result", {})
			_expect_eq(bool(result.get("success", false)), true, "xAPI success")
			var extensions: Dictionary = result.get("extensions", {})
			_expect_eq(int(extensions.get("wait_time_ms", 0)), 3100, "xAPI wait_time_ms")

	if ui_event.is_empty():
		_fail("Missing UI button payload")
	else:
		_expect_eq(ui_event.get("text", ""), "Probe Button", "button text")
		if str(ui_event.get("path", "")) == "":
			_fail("UI button event missing node path")

	if item_event.is_empty():
		_fail("Missing item event payload")
	else:
		_expect_eq(item_event.get("item_id", ""), "noticing_lens", "item id")

	print("TELEMETRY path=%s lines=%d events=%s" % [Telemetry._path, line_count, str(events.keys())])

func _expect_eq(actual, expected, label: String) -> void:
	if actual != expected:
		_fail("%s expected=%s actual=%s" % [label, str(expected), str(actual)])

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish() -> void:
	if _failures.is_empty():
		print("TELEMETRY TEST: PASS")
	else:
		print("TELEMETRY TEST: FAIL")
		for msg in _failures:
			print(" - %s" % msg)
	get_tree().quit()
