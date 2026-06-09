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
				if role == "learner":
					GameState.apply_course_baseline(class_code)
				_unlock_voice_then_login(p_password)
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

## Unauthenticated POST (anonymous/demo telemetry). No Bearer header; only the namespaced
## anon_id in the body identifies the session. No-op if the API is not provisioned.
func post_anon(path: String, body: Dictionary, cb: Callable = Callable()) -> void:
	if not configured():
		return
	_post(path, body, false, func(ok, data):
		if cb.is_valid():
			cb.call(ok, data))

## Unload-safe POST for telemetry that MUST survive a tab close. On web we use
## fetch(keepalive:true) — unlike a normal HTTPRequest, the browser guarantees delivery
## even if the page is unloading right after the call. Off web (desktop/headless) there is
## no unload race, so fall back to the normal async POST. authed=false omits the Bearer
## header for the anonymous demo path.
func beacon(path: String, body: Dictionary, authed := true) -> bool:
	if authed and not signed_in():
		return false
	if not authed and not configured():
		return false
	if OS.has_feature("web"):
		var headers_js := "{'Content-Type':'application/json','Authorization':'Bearer '+token}" if authed \
			else "{'Content-Type':'application/json'}"
		var js := """
		(function(url, token, payload){
		  try {
		    fetch(url, {method:'POST', keepalive:true,
		      headers:%s,
		      body: payload});
		    return true;
		  } catch (e) { return false; }
		})(%s, %s, %s);
		""" % [headers_js, JSON.stringify(api_base + path), JSON.stringify(token), JSON.stringify(JSON.stringify(body))]
		JavaScriptBridge.eval(js, true)
		return true
	if authed:
		post_authed(path, body)
	else:
		post_anon(path, body)
	return true

func get_authed(path: String, cb: Callable = Callable()) -> void:
	if not signed_in():
		return
	_request(path, HTTPClient.METHOD_GET, {}, true, func(ok, data):
		if cb.is_valid():
			cb.call(ok, data))

func _load_competency_then_login() -> void:
	get_authed("/competency", func(ok: bool, data):
		if ok and typeof(data) == TYPE_DICTIONARY and typeof(data.get("skills", [])) == TYPE_ARRAY:
			Competency.load_cloud_summary(data.get("skills", []))
		login_ok.emit())

func _unlock_voice_then_login(passcode: String) -> void:
	if TTSClient.voice_gate_required and not TTSClient.voice_gate_unlocked and passcode.strip_edges() != "":
		_post("/voice_token", {"passcode": passcode}, false, func(ok: bool, data):
			if ok and typeof(data) == TYPE_DICTIONARY and str(data.get("token", "")).strip_edges() != "":
				TTSClient.unlock_voice_token(str(data.get("token", "")))
			_load_competency_then_login())
	else:
		_load_competency_then_login()

# --- internal: one fresh HTTPRequest per call (avoids busy conflicts) ---------
func _post(path: String, body: Dictionary, authed: bool, cb: Callable) -> void:
	_request(path, HTTPClient.METHOD_POST, body, authed, cb)

func _request(path: String, method: int, body: Dictionary, authed: bool, cb: Callable) -> void:
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
	var request_body := "" if method == HTTPClient.METHOD_GET else JSON.stringify(body)
	var err := http.request(api_base + path, headers, method, request_body)
	if err != OK:
		cb.call(false, null)
		http.queue_free()
