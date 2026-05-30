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
		var base := _web_api_base()
		if base != "":
			endpoint = base + "/tts"
		else:
			enabled = false  # no hosted endpoint configured; stay silent

func _web_api_base() -> String:
	var f := FileAccess.open("res://data/auth_config.json", FileAccess.READ)
	if f == null:
		return ""
	var cfg = JSON.parse_string(f.get_as_text())
	f.close()
	return str(cfg.get("api_base", "")).strip_edges().rstrip("/") if typeof(cfg) == TYPE_DICTIONARY else ""

func speak(persona_id: String, text: String, emotion: String = "neutral") -> void:
	if not enabled or text.strip_edges() == "":
		return
	_http.cancel_request()
	if _player.playing:
		_player.stop()
	var payload := {"persona_id": persona_id, "text": text, "emotion": emotion}
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := _http.request(endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		push_warning("TTSClient: request error %d (silent)" % err)

func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or body.size() < 64:
		return  # 204/down/empty -> stay silent
	var stream := AudioStreamMP3.new()
	stream.data = body
	_player.stream = stream
	_player.play()
