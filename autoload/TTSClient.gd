extends Node
## Speaks student lines aloud via the backend /tts endpoint (ElevenLabs per-persona
## child-ish voices). Audio is optional: if the backend is down or returns no audio
## (204), the game stays silent and never errors. Latest request wins (we cancel an
## in-flight clip when a new line arrives).

@export var endpoint: String = "http://127.0.0.1:8008/tts"
@export var enabled: bool = true
@export var timeout_seconds: float = 20.0

var _http: HTTPRequest
var _player: AudioStreamPlayer
var voice_gate_required := false
var voice_gate_unlocked := false
var _voice_gate_code := ""

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.timeout = timeout_seconds
	_http.request_completed.connect(_on_done)
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	add_child(_player)
	# Web build speaks through the hosted Worker /tts (ElevenLabs proxy); desktop uses
	# the local backend. Both return raw mp3 -> AudioStreamMP3.
	if OS.has_feature("web"):
		var cfg := _web_auth_config()
		var base := str(cfg.get("api_base", "")).strip_edges().rstrip("/") if typeof(cfg) == TYPE_DICTIONARY else ""
		if base != "":
			endpoint = base + "/tts"
			voice_gate_required = bool(cfg.get("tts_requires_gate", true))
			_voice_gate_code = str(cfg.get("tts_gate_code", "")).strip_edges()
			voice_gate_unlocked = (not voice_gate_required) or _web_voice_gate_ok(_voice_gate_code)
			enabled = voice_gate_unlocked
		else:
			enabled = false  # no hosted endpoint configured; stay silent

func _web_auth_config() -> Dictionary:
	var f := FileAccess.open("res://data/auth_config.json", FileAccess.READ)
	if f == null:
		return {}
	var cfg = JSON.parse_string(f.get_as_text())
	f.close()
	return cfg if typeof(cfg) == TYPE_DICTIONARY else {}

func _web_voice_gate_ok(code: String) -> bool:
	if code.strip_edges() == "":
		return false
	if not OS.has_feature("web"):
		return true
	var token := ""
	if ClassDB.class_exists("JavaScriptBridge"):
		token = str(JavaScriptBridge.eval("(new URLSearchParams(window.location.search).get('voice') || new URLSearchParams(window.location.hash.slice(1)).get('voice') || '')", true))
	return token.strip_edges() == code.strip_edges()

func speak(persona_id: String, text: String, emotion: String = "neutral") -> void:
	if not enabled or text.strip_edges() == "" or not bool(GameState.get_setting("audio_enabled", true)):
		return
	_http.cancel_request()
	if _player.playing:
		_player.stop()
	var payload := {"persona_id": persona_id, "text": text, "emotion": emotion}
	var headers := PackedStringArray(["Content-Type: application/json"])
	if OS.has_feature("web") and _voice_gate_code != "" and voice_gate_unlocked:
		headers.append("X-Voice-Gate: %s" % _voice_gate_code)
	var err := _http.request(endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		push_warning("TTSClient: request error %d (silent)" % err)

func voice_status_label() -> String:
	if voice_gate_required and not voice_gate_unlocked:
		return "Voice: Off (demo gate)"
	return "Voice: On" if enabled else "Voice: Off"

func voice_status_detail() -> String:
	if voice_gate_required and not voice_gate_unlocked:
		return "Voice is off in the public demo to prevent ElevenLabs charges. Use the passcode gate for voice."
	if enabled:
		return "Voice is enabled. Sound toggles both SFX and spoken student lines."
	return "Voice is unavailable because no TTS endpoint is configured."

func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or body.size() < 64:
		return  # 204/down/empty -> stay silent
	var stream := AudioStreamMP3.new()
	stream.data = body
	_player.stream = stream
	_player.play()
