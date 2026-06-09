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
var _last_flush_ms := 0
const AUTO_FLUSH_MS := 12000  ## push buffered events to the cloud at least this often
var anon_id: String = ""      ## stable per-browser id for un-logged-in (demo) play
var _session_start_ms := 0
var _last_heartbeat_ms := 0
const HEARTBEAT_MS := 30000   ## periodic "still here" pulse so engagement/dwell is minable

var _net := true   ## false under the headless driver so automated test runs never hit live D1

func _ready() -> void:
	_net = DisplayServer.get_name() != "headless"
	session_id = "sess_%d_%d" % [int(Time.get_unix_time_from_system()), (Time.get_ticks_usec() % 100000)]
	anon_id = _load_or_make_anon_id()
	_session_start_ms = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute("user://telemetry")
	_path = "user://telemetry/%s.jsonl" % session_id
	_f = FileAccess.open(_path, FileAccess.WRITE)
	log_event({
		"event": "session_start", "engine": Engine.get_version_info().get("string", ""),
		"client": _client_context(),
	})
	set_process_input(true)
	set_process(true)

## A stable anonymous id persisted in user:// so repeat demo visits from the same browser
## attribute to one anon learner (web: IndexedDB-backed user://).
func _load_or_make_anon_id() -> String:
	var p := "user://anon_id.txt"
	if FileAccess.file_exists(p):
		var rf := FileAccess.open(p, FileAccess.READ)
		if rf != null:
			var s := rf.get_as_text().strip_edges()
			rf.close()
			if s != "":
				return s
	var made := "a_%d_%d" % [int(Time.get_unix_time_from_system()), (Time.get_ticks_usec() % 1000000)]
	var wf := FileAccess.open(p, FileAccess.WRITE)
	if wf != null:
		wf.store_string(made)
		wf.close()
	return made

## Where the player is connecting from + their setup (web only; server adds CF geo).
func _client_context() -> Dictionary:
	var ctx := {"platform": OS.get_name(), "locale": OS.get_locale()}
	if OS.has_feature("web"):
		ctx["url"] = str(JavaScriptBridge.eval("window.location.href", true))
		ctx["referrer"] = str(JavaScriptBridge.eval("document.referrer", true))
		ctx["ua"] = str(JavaScriptBridge.eval("navigator.userAgent", true))
		ctx["lang"] = str(JavaScriptBridge.eval("navigator.language", true))
		ctx["screen"] = str(JavaScriptBridge.eval("window.screen.width + 'x' + window.screen.height", true))
		ctx["tz"] = str(JavaScriptBridge.eval("Intl.DateTimeFormat().resolvedOptions().timeZone", true))
	return ctx

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	# Time-based flush so a player who acts a little and then idles/leaves still
	# lands their events in the cloud, even if the buffer never reaches the size gate.
	if not _buffer.is_empty() and now - _last_flush_ms >= AUTO_FLUSH_MS:
		_last_flush_ms = now
		flush()
	# Engagement pulse: lets "how much / how long they played" be reconstructed even for a
	# player who only wanders and never completes an encounter.
	if now - _last_heartbeat_ms >= HEARTBEAT_MS:
		_last_heartbeat_ms = now
		if now - _session_start_ms > HEARTBEAT_MS - 1000:
			log_event({"event": "heartbeat", "elapsed_s": (now - _session_start_ms) / 1000, "scene": _scene_name()})
	if now - _last_button_scan_ms < 500:
		return
	_last_button_scan_ms = now
	var root := get_tree().root
	if root != null:
		_scan_buttons(root)

## Tab close / app background / quit: get whatever is buffered to the cloud NOW,
## before the page can unload. On web this uses a keepalive fetch that survives unload.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_WINDOW_FOCUS_OUT, \
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, \
		NOTIFICATION_EXIT_TREE, NOTIFICATION_CRASH:
			flush_sync()

## Best-effort synchronous flush: hand the entire buffer to the unload-safe beacon.
## We clear locally because the keepalive request is fire-and-forget (no callback on unload).
func flush_sync() -> void:
	if _f != null:
		_f.flush()
	if not _net or not Auth.configured() or _buffer.is_empty():
		return
	var ok := false
	if Auth.signed_in():
		ok = Auth.beacon("/telemetry", {"events": _buffer.duplicate()})
	else:
		ok = Auth.beacon("/telemetry_anon", {"anon_id": anon_id, "events": _buffer.duplicate()}, false)
	if ok:
		_buffer.clear()

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
	# Stamp the learner identity so the cloud row attributes to the right person; for demo
	# (not signed in) play we stamp the anonymous id instead so it is still attributable.
	if Auth.signed_in():
		d["user_id"] = Auth.user_id
		d["learner"] = Auth.display_name
		d["class_code"] = Auth.class_code
	else:
		d["anon_id"] = anon_id
	_write(d)
	# Always buffer for cloud upload (signed-in OR anonymous demo). Buffering does not
	# depend on Auth being loaded yet, so the very first session_start is never lost.
	_buffer.append(d)
	if _buffer.size() > 256:
		_buffer = _buffer.slice(_buffer.size() - 256)
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

## Upload buffered events to the cloud (no-op if the API is not provisioned). Routes to the
## authed endpoint when signed in, otherwise to the anonymous demo endpoint. Call at lesson end.
func flush() -> void:
	if not _net or not Auth.configured() or _buffer.is_empty() or _flush_in_flight:
		return
	var payload := _buffer.duplicate()
	_flush_in_flight = true
	_last_flush_ms = Time.get_ticks_msec()
	var on_done := func(ok: bool, _data):
		_flush_in_flight = false
		if not ok:
			return
		var sent_count := mini(payload.size(), _buffer.size())
		for _i in range(sent_count):
			_buffer.remove_at(0)
		if _buffer.size() >= 8:
			flush()
	if Auth.signed_in():
		Auth.post_authed("/telemetry", {"events": payload}, on_done)
	else:
		Auth.post_anon("/telemetry_anon", {"anon_id": anon_id, "events": payload}, on_done)

## Push the current ECD competency estimate to the learner's account.
func upload_competency() -> void:
	if not _net or not Auth.signed_in():
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
