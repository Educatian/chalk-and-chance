extends Node
## Structured input<->output logging for analysis (ties into the PlayTrace / OGD line).
## Every encounter turn is recorded as one JSONL line (raw fields + an xAPI-style
## statement) under user://telemetry/<session>.jsonl. Deterministic-safe: no network
## needed; writing failures never interrupt play.

var session_id: String = ""
var _path: String = ""
var _f: FileAccess = null
var enabled: bool = true
var capture_raw_input: bool = true
var capture_mouse_motion: bool = true
var _last_button_scan_ms := 0
var _last_mouse_motion_ms := 0
var _last_mouse_pos := Vector2.INF

func _ready() -> void:
	session_id = "sess_%d_%d" % [int(Time.get_unix_time_from_system()), (Time.get_ticks_usec() % 100000)]
	DirAccess.make_dir_recursive_absolute("user://telemetry")
	_path = "user://telemetry/%s.jsonl" % session_id
	_f = FileAccess.open(_path, FileAccess.WRITE)
	log_event({"event": "session_start", "engine": Engine.get_version_info().get("string", "")})
	set_process_input(true)
	set_process(true)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_button_scan_ms < 500:
		return
	_last_button_scan_ms = now
	var root := get_tree().root
	if root != null:
		_scan_buttons(root)

func _input(event: InputEvent) -> void:
	if not capture_raw_input:
		return
	if event is InputEventKey:
		var ev := event as InputEventKey
		log_event({
			"event": "input_key",
			"pressed": ev.pressed,
			"echo": ev.echo,
			"keycode": ev.keycode,
			"physical_keycode": ev.physical_keycode,
			"key_label": OS.get_keycode_string(ev.keycode),
			"unicode": ev.unicode,
			"scene": _scene_name(),
		})
	elif event is InputEventMouseButton:
		var evm := event as InputEventMouseButton
		log_event({
			"event": "input_mouse_button",
			"pressed": evm.pressed,
			"button_index": evm.button_index,
			"position": _vec2_dict(evm.position),
			"scene": _scene_name(),
		})
	elif event is InputEventMouseMotion and capture_mouse_motion:
		var mov := event as InputEventMouseMotion
		var now := Time.get_ticks_msec()
		if now - _last_mouse_motion_ms >= 120 and (_last_mouse_pos == Vector2.INF or _last_mouse_pos.distance_to(mov.position) >= 8.0):
			_last_mouse_motion_ms = now
			_last_mouse_pos = mov.position
			log_event({
				"event": "input_mouse_motion",
				"position": _vec2_dict(mov.position),
				"relative": _vec2_dict(mov.relative),
				"scene": _scene_name(),
			})
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		log_event({
			"event": "input_touch",
			"pressed": touch.pressed,
			"index": touch.index,
			"position": _vec2_dict(touch.position),
			"scene": _scene_name(),
		})
	elif event is InputEventJoypadButton:
		var joy := event as InputEventJoypadButton
		log_event({
			"event": "input_joy_button",
			"pressed": joy.pressed,
			"device": joy.device,
			"button_index": joy.button_index,
			"scene": _scene_name(),
		})
	elif event is InputEventJoypadMotion:
		var axis := event as InputEventJoypadMotion
		if absf(axis.axis_value) >= 0.25:
			log_event({
				"event": "input_joy_motion",
				"device": axis.device,
				"axis": axis.axis,
				"value": axis.axis_value,
				"scene": _scene_name(),
			})

func _write(d: Dictionary) -> void:
	if not enabled or _f == null:
		return
	_f.store_line(JSON.stringify(d))
	_f.flush()

var _buffer: Array = []   # events pending upload to the learner's cloud account
var _flush_in_flight := false

## Generic event line (session_start/resolve/fail/etc.).
func log_event(d: Dictionary) -> void:
	d["session_id"] = session_id
	d["t_ms"] = Time.get_ticks_msec()
	d["unix"] = Time.get_unix_time_from_system()
	# Stamp the learner identity so the cloud row attributes to the right person.
	if Auth.signed_in():
		d["user_id"] = Auth.user_id
		d["learner"] = Auth.display_name
		d["class_code"] = Auth.class_code
	_write(d)
	if Auth.signed_in():
		_buffer.append(d)
		if _buffer.size() >= 8:
			flush()

func log_player_movement(kind: String, data: Dictionary) -> void:
	data["event"] = "player_movement"
	data["kind"] = kind
	data["scene"] = _scene_name()
	log_event(data)

func log_ui_button(button: Button) -> void:
	if button == null or not is_instance_valid(button):
		return
	log_event({
		"event": "ui_button_pressed",
		"text": button.text,
		"disabled": button.disabled,
		"path": str(button.get_path()),
		"scene": _scene_name(),
	})

func _scan_buttons(node: Node) -> void:
	if node is Button:
		var b := node as Button
		if not bool(b.get_meta("_telemetry_connected", false)):
			b.set_meta("_telemetry_connected", true)
			b.pressed.connect(log_ui_button.bind(b))
	for child in node.get_children():
		_scan_buttons(child)

func _scene_name() -> String:
	if SceneRouter.has_method("active_scene_name"):
		var routed := str(SceneRouter.active_scene_name())
		if routed != "":
			return routed
	var current := get_tree().current_scene
	if current != null:
		return current.scene_file_path if current.scene_file_path != "" else current.name
	return ""

func _vec2_dict(v: Vector2) -> Dictionary:
	return {"x": v.x, "y": v.y}

## Upload buffered events under the signed-in learner (no-op offline). Call at lesson end.
func flush() -> void:
	if not Auth.signed_in() or _buffer.is_empty() or _flush_in_flight:
		return
	var payload := _buffer.duplicate()
	_flush_in_flight = true
	Auth.post_authed("/telemetry", {"events": payload}, func(ok: bool, _data):
		_flush_in_flight = false
		if not ok:
			return
		var sent_count := mini(payload.size(), _buffer.size())
		for _i in range(sent_count):
			_buffer.remove_at(0)
		if _buffer.size() >= 8:
			flush())

## Push the current ECD competency estimate to the learner's account.
func upload_competency() -> void:
	if not Auth.signed_in():
		return
	var skills: Array = []
	for r in Competency.summary():
		if r["n"] > 0:
			skills.append({"skill": r["skill"], "theta": Competency.theta.get(r["skill"], 0.0),
				"prob": r["prob"], "n": r["n"]})
	if not skills.is_empty():
		Auth.post_authed("/competency", {"skills": skills})

## One teacher-move turn: the player INPUT, the judge/meter OUTPUT, and the student's
## generated reaction. `e` carries scenario_id/persona_id/turn/move/judge/deltas/meters/
## emotion_shown/student_text/resolved. We also emit a compact xAPI statement.
# move tag -> the competency construct it provides evidence for (mirrors
# data/competency_model.json evidence_rules; OGD/construct-aware telemetry).
const TAG_CONSTRUCT := {
	"elicit": "elicit_reasoning", "extend": "extend_thinking", "revoice": "revoicing",
	"wait": "wait_time", "redirect": "behavior_mgmt", "tell": "restraint",
	"praise": "behavior_specific_praise", "connect": "funds_of_knowledge",
}

func log_turn(e: Dictionary) -> void:
	var move: Dictionary = e.get("move", {})
	var judge: Dictionary = e.get("judge", {})
	var tag: String = str(move.get("tag", ""))
	e["construct_id"] = TAG_CONSTRUCT.get(tag, "")
	var verb: String = {
		"elicit": "elicited", "extend": "extended", "revoice": "revoiced",
		"tell": "told", "praise": "praised", "redirect": "redirected",
		"wait": "waited", "connect": "connected",
	}.get(tag, "acted")
	e["xapi"] = {
		"actor": {"name": "teacher", "session": session_id},
		"verb": verb,
		"object": {"persona_id": e.get("persona_id", ""), "scenario_id": e.get("scenario_id", "")},
		"result": {
			"success": bool(judge.get("targets", false)),
			"response": str(e.get("emotion_shown", "")),
			"extensions": {
				"wait_time_ms": int(move.get("wait_ms", 0)),
				"wait_ok": bool(judge.get("wait_ok", false)),
				"understanding": e.get("meters", {}).get("understanding", 0.0),
			},
		},
		"context": {"turn": e.get("turn", 0), "input_mode": str(move.get("input_mode", "menu"))},
	}
	e["event"] = "turn"
	log_event(e)
