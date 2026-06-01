extends Node
## Browser speech-to-text helper for Godot Web exports. It uses the Web Speech API
## through JavaScriptBridge and quietly disables itself outside supported browsers.

signal listening_started
signal listening_finished
signal transcript_ready(text: String)
signal voice_error(message: String)

var _initialized := false
var _supported := false
var _polling := false
var _target: LineEdit = null

func is_supported() -> bool:
	return _ensure_js()

func start_for_line_edit(target: LineEdit, lang: String = "en-US") -> bool:
	if target == null:
		return false
	if not _ensure_js():
		voice_error.emit("Voice input is not available in this browser.")
		return false
	_target = target
	JavaScriptBridge.eval("window.__chalkVoiceInput.start(%s);" % JSON.stringify(lang), true)
	_polling = true
	set_process(true)
	listening_started.emit()
	return true

func stop() -> void:
	if _supported:
		JavaScriptBridge.eval("window.__chalkVoiceInput.stop();", true)
	_finish_polling()

func _ready() -> void:
	set_process(false)

func _process(_delta: float) -> void:
	if not _polling or not _supported:
		return
	var status := str(JavaScriptBridge.eval("window.__chalkVoiceInput ? window.__chalkVoiceInput.status : 'unsupported';", true))
	var transcript := str(JavaScriptBridge.eval("window.__chalkVoiceInput ? window.__chalkVoiceInput.transcript : '';", true)).strip_edges()
	var err := str(JavaScriptBridge.eval("window.__chalkVoiceInput ? window.__chalkVoiceInput.error : '';", true)).strip_edges()
	if transcript != "":
		if _target != null and is_instance_valid(_target):
			_target.text = transcript
			_target.caret_column = transcript.length()
			_target.grab_focus()
		JavaScriptBridge.eval("window.__chalkVoiceInput.transcript = '';", true)
		transcript_ready.emit(transcript)
		_finish_polling()
	elif err != "":
		JavaScriptBridge.eval("window.__chalkVoiceInput.error = '';", true)
		voice_error.emit(err)
		_finish_polling()
	elif status == "idle" or status == "unsupported":
		_finish_polling()

func _finish_polling() -> void:
	if _polling:
		listening_finished.emit()
	_polling = false
	set_process(false)

func _ensure_js() -> bool:
	if not OS.has_feature("web"):
		return false
	if _initialized:
		return _supported
	_initialized = true
	var code := """
(function () {
	if (window.__chalkVoiceInput) return window.__chalkVoiceInput.supported === true;
	const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
	window.__chalkVoiceInput = {
		supported: !!SpeechRecognition,
		status: SpeechRecognition ? "idle" : "unsupported",
		transcript: "",
		error: "",
		recognition: null,
		start: function (lang) {
			if (!this.supported) {
				this.status = "unsupported";
				this.error = "Voice input is not supported in this browser.";
				return;
			}
			if (this.status === "listening") return;
			this.transcript = "";
			this.error = "";
			const rec = new SpeechRecognition();
			this.recognition = rec;
			rec.lang = lang || "en-US";
			rec.interimResults = false;
			rec.maxAlternatives = 1;
			rec.onstart = () => { this.status = "listening"; };
			rec.onresult = (event) => {
				let text = "";
				for (let i = event.resultIndex; i < event.results.length; i++) {
					text += event.results[i][0].transcript;
				}
				this.transcript = text.trim();
			};
			rec.onerror = (event) => {
				this.error = event.error || "speech_error";
				this.status = "idle";
			};
			rec.onend = () => { this.status = "idle"; };
			try { rec.start(); } catch (e) {
				this.error = e && e.message ? e.message : "speech_start_failed";
				this.status = "idle";
			}
		},
		stop: function () {
			if (this.recognition) this.recognition.stop();
			this.status = "idle";
		}
	};
	return window.__chalkVoiceInput.supported === true;
})()
"""
	_supported = bool(JavaScriptBridge.eval(code, true))
	return _supported
