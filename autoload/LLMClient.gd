extends Node
## Wraps the Godot <-> LLM /turn contract (GAME_CONCEPT.md section 7.6).
## In M1 it runs a local STUB whose judge deltas follow the literature-tagged
## rubric of section 7.4. Set use_stub=false (and run tools/llm_backend) for the
## real hybrid backend in Phase 2.

signal reply_ready(response: Dictionary)
signal request_failed(message: String)

@export var endpoint: String = "http://127.0.0.1:8008/turn"
@export var use_stub: bool = false
@export var timeout_seconds: float = 12.0

var _http: HTTPRequest
var _last_payload: Dictionary = {}

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.timeout = timeout_seconds
	_http.request_completed.connect(_on_request_completed)
	# The web build can't reach the local FastAPI backend, so it talks to the hosted
	# Cloudflare Worker /turn (real Gemini students). Desktop keeps the local backend.
	if OS.has_feature("web"):
		if _web_public_demo_mode():
			use_stub = true
		var base := _read_api_base()
		if base != "":
			endpoint = base.rstrip("/") + "/turn"

func _web_public_demo_mode() -> bool:
	if not OS.has_feature("web"):
		return false
	if ClassDB.class_exists("JavaScriptBridge"):
		var raw := str(JavaScriptBridge.eval("(new URLSearchParams(window.location.search).get('public_demo') || new URLSearchParams(window.location.hash.slice(1)).get('public_demo') || '')", true)).strip_edges().to_lower()
		return raw == "1" or raw == "true" or raw == "yes"
	return false

func _read_api_base() -> String:
	var f := FileAccess.open("res://data/auth_config.json", FileAccess.READ)
	if f == null:
		return ""
	var cfg = JSON.parse_string(f.get_as_text())
	f.close()
	return str(cfg.get("api_base", "")).strip_edges() if typeof(cfg) == TYPE_DICTIONARY else ""

## payload follows the request shape in GAME_CONCEPT.md 7.6
func send_move(payload: Dictionary) -> void:
	_last_payload = payload
	if use_stub:
		call_deferred("_emit_stub", payload)
		return
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify(payload)
	var err := _http.request(endpoint, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		push_warning("LLMClient: HTTP request error %d, falling back to stub" % err)
		_emit_stub(payload)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("LLMClient: backend error (result %d, code %d), falling back to stub" % [result, response_code])
		request_failed.emit("backend error (result %d, code %d)" % [result, response_code])
		_emit_stub(_last_payload)
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("LLMClient: malformed JSON, falling back to stub")
		request_failed.emit("backend returned malformed JSON")
		_emit_stub(_last_payload)
		return
	reply_ready.emit(parsed)

# --- M1 stub -----------------------------------------------------------------
# Deterministic judge-before-generate rubric. Tag -> meter deltas mirror the
# fixed table in GAME_CONCEPT.md 7.4. understanding only rises on
# targets_misconception moves (anti-sycophancy gate).

func _emit_stub(payload: Dictionary) -> void:
	var move: Dictionary = payload.get("teacher_move", {})
	var tag: String = str(move.get("menu_tag", ""))
	if tag == "" and str(move.get("input_mode", "")) == "free_text":
		tag = _classify_stub_text(str(move.get("text", "")))
	var wait_ms: int = int(move.get("wait_time_ms", 0))
	var wait_ok: bool = wait_ms >= 3000
	var win_moves: Array = payload.get("win_moves", ["elicit", "extend", "revoice", "wait"])

	# "targets" = this is the move that actually works for THIS student (drives resolution).
	var targets := false
	if tag == "wait":
		targets = ("wait" in win_moves) and wait_ok
	elif tag != "tell" and tag != "":
		targets = tag in win_moves

	var deltas := {"understanding": 0.0, "trust": 0.0, "engagement": 0.0, "order": 0.0, "composure": 0.0}
	var text := "..."
	var coach := ""
	var feedback_type := "none"

	match tag:
		"elicit":
			deltas = {"understanding": 0.0, "trust": 0.02, "engagement": 0.06, "order": 0.0, "composure": 0.02}
			feedback_type = "process"
			text = "Okay... let me walk you through how I was thinking about it."
			coach = "Good eliciting move; you surfaced their reasoning instead of correcting it. Press on the crack."
		"extend":
			deltas = {"understanding": 0.0, "trust": 0.0, "engagement": 0.04, "order": 0.0, "composure": 0.0}
			feedback_type = "process"
			text = "Hmm, now I'm not so sure about my first answer."
			coach = "Nice press. They are reasoning it through themselves instead of being told."
		"revoice":
			deltas = {"understanding": 0.04, "trust": 0.10, "engagement": 0.05, "order": 0.0, "composure": 0.0}
			text = "Yeah, that's what I meant."
			coach = "Revoicing builds rapport and makes their thinking public. The move new teachers skip most."
		"tell":
			deltas = {"understanding": 0.0, "trust": -0.05, "engagement": -0.10, "order": 0.02, "composure": -0.05}
			text = "Oh. Okay, I guess."
			coach = "You took over the thinking, so engagement dropped. Necessary sometimes, but try eliciting first."
		"praise":
			deltas = {"understanding": 0.0, "trust": 0.08, "engagement": 0.02, "order": 0.05, "composure": 0.02}
			text = "...thanks."
			coach = "Make praise behavior-specific (name what they did), not 'good job'. Generic praise barely moves the needle."
		"redirect":
			deltas = {"understanding": 0.0, "trust": -0.02, "engagement": 0.0, "order": 0.06, "composure": 0.0}
			text = "Okay, sorry."
			coach = "Use the least-intrusive redirect that works (proximity or nonverbal before a verbal correction)."
		"wait":
			if wait_ok:
				deltas = {"understanding": 0.0, "trust": 0.04, "engagement": 0.06, "order": 0.0, "composure": 0.03}
				text = "...oh, wait, maybe I had it backwards."
				coach = "Wait time paid off. They filled the silence with their own reasoning. Three to five seconds is the sweet spot."
			else:
				deltas = {"understanding": 0.0, "trust": -0.05, "engagement": -0.02, "order": 0.0, "composure": -0.02}
				text = "..."
				coach = "You broke the silence too early. Hold the pause at least three seconds."
		_:
			coach = "Pick a teaching move."

	# Resolution only advances on the move that works for THIS student (differentiated win).
	deltas["understanding"] = 0.12 if targets else 0.0
	if not targets and tag != "" and tag != "tell":
		coach += "  (For this student, that may not be the move that unlocks them - check the goal at the top.)"

	var resp := {
		"judge": {
			"move_tags": [tag],
			"targets_misconception": targets,
			"feedback_type": feedback_type,
			"wait_time_ok": wait_ok,
		},
		"meter_deltas": deltas,
		"student_utterance": {"speaker": str(payload.get("display_name", payload.get("active_persona_id", "Student"))), "text": text},
		"coach_tip": coach,
	}
	reply_ready.emit(resp)

func _classify_stub_text(text: String) -> String:
	var t := text.to_lower()
	if t.find("walk me through") >= 0 or t.find("how did") >= 0 or t.find("how you got") >= 0 or t.find("explain your thinking") >= 0:
		return "elicit"
	if t.find("what if") >= 0 or t.find("why") >= 0 or t.find("push") >= 0 or t.find("another way") >= 0:
		return "extend"
	if t.find("so you") >= 0 or t.find("what i hear") >= 0 or t.find("you are saying") >= 0 or t.find("restate") >= 0:
		return "revoice"
	if t.find("good") >= 0 or t.find("nice") >= 0 or t.find("i like") >= 0 or t.find("you did") >= 0:
		return "praise"
	if t.find("focus") >= 0 or t.find("back to") >= 0 or t.find("turn") >= 0 or t.find("voice") >= 0:
		return "redirect"
	if t.find("wait") >= 0 or t.find("take your time") >= 0 or t.find("think") >= 0:
		return "wait"
	if t.find("because") >= 0 or t.find("show") >= 0 or t.find("answer is") >= 0:
		return "tell"
	return "elicit"
