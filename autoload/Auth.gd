extends Node
## Per-learner identity over the Cloudflare Worker API (cloudflare/worker.js).
## Login = class code + name + password (named accounts, like Design Tension Studio).
## Holds the JWT; Telemetry/Competency upload under this learner. If api_base is empty
## (not provisioned yet) the game runs offline and the login screen is skipped.

signal login_ok()
signal login_failed(message: String)

var api_base: String = ""
var token: String = ""
var user_id: String = ""
var display_name: String = ""
var class_code: String = ""
var role: String = ""

func _ready() -> void:
	var f := FileAccess.open("res://data/auth_config.json", FileAccess.READ)
	if f != null:
		var cfg = JSON.parse_string(f.get_as_text())
		f.close()
		if typeof(cfg) == TYPE_DICTIONARY:
			api_base = str(cfg.get("api_base", "")).strip_edges().rstrip("/")

func configured() -> bool:
	return api_base != ""

func signed_in() -> bool:
	return token != ""

func login(p_class: String, p_name: String, p_password: String) -> void:
	if not configured():
		login_failed.emit("login not set up yet")
		return
	_post("/auth/login", {"class_code": p_class, "name": p_name, "password": p_password}, false,
		func(ok: bool, data):
			if ok and typeof(data) == TYPE_DICTIONARY and data.has("token"):
				token = str(data["token"])
				user_id = str(data.get("user_id", ""))
				display_name = str(data.get("display_name", p_name))
				class_code = str(data.get("class_code", p_class))
				role = str(data.get("role", "learner"))
				login_ok.emit()
			else:
				var msg := "login failed"
				if typeof(data) == TYPE_DICTIONARY:
					msg = str(data.get("error", msg))
				login_failed.emit(msg))

## Authenticated POST (used by Telemetry/Competency upload). Silent by default,
## but callers can pass a callback when they need retry-safe buffering.
func post_authed(path: String, body: Dictionary, cb: Callable = Callable()) -> void:
	if not signed_in():
		return
	_post(path, body, true, func(ok, data):
		if cb.is_valid():
			cb.call(ok, data))

# --- internal: one fresh HTTPRequest per call (avoids busy conflicts) ---------
func _post(path: String, body: Dictionary, authed: bool, cb: Callable) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = 15.0
	http.request_completed.connect(func(result, code, _h, resp):
		var data = JSON.parse_string(resp.get_string_from_utf8()) if resp.size() > 0 else null
		cb.call(result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300, data)
		http.queue_free())
	var headers := PackedStringArray(["Content-Type: application/json"])
	if authed:
		headers.append("Authorization: Bearer " + token)
	var err := http.request(api_base + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		cb.call(false, null)
		http.queue_free()
