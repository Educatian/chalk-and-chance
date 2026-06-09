extends Control
## Import-a-lesson screen. Paste/load a plan, then generate a scenario either OFFLINE
## (LessonImport heuristic, no backend) or WITH AI (POST to the FastAPI /lesson_to_scenario
## backend for content-specific dialogue; falls back to offline if unreachable). Generation
## routes to the Preview screen so the teacher can review/tweak before playing.

const LessonImport = preload("res://scripts/LessonImport.gd")
const ENDPOINT := "http://127.0.0.1:8000/lesson_to_scenario"

var _text: TextEdit
var _status: Label
var _dialog: FileDialog
var _http: HTTPRequest
var _pending_text := ""
var _gen_btn: Button
var _genai_btn: Button

func _ready() -> void:
	_build()

func setup(_data: Dictionary) -> void:
	pass

func _build() -> void:
	var vp := get_viewport_rect().size

	var bg := ColorRect.new()
	bg.size = vp
	bg.color = Color(0.07, 0.09, 0.16)
	add_child(bg)

	var title := Label.new()
	title.text = "IMPORT A LESSON PLAN"
	title.position = Vector2(40, 28)
	title.add_theme_font_override("font", load("res://ui/fonts/PressStart2P-Regular.ttf"))
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.97, 0.95, 0.86))
	add_child(title)

	var sub := Label.new()
	sub.text = "Paste your plan (or load a .txt/.md). Activity format sets seating; duration sets the period.\nObjectives become goals, and 'AI' rewrites student dialogue to match your content."
	sub.position = Vector2(42, 66)
	sub.size = Vector2(vp.x - 84, 44)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	add_child(sub)

	_text = TextEdit.new()
	_text.position = Vector2(42, 112)
	_text.size = Vector2(vp.x - 84, vp.y - 234)
	_text.placeholder_text = "e.g.\nGrade: 5\nSubject: Comparing Decimals\nDuration: 45 minutes\nFormat: whole-class discussion / number talk\nObjectives: compare decimals by place value..."
	_text.add_theme_font_size_override("font_size", 15)
	add_child(_text)

	_status = Label.new()
	_status.position = Vector2(42, vp.y - 114)
	_status.size = Vector2(vp.x - 84, 22)
	_status.add_theme_font_size_override("font_size", 14)
	_status.add_theme_color_override("font_color", Color(0.72, 0.92, 0.78))
	add_child(_status)

	var by := vp.y - 78
	var bw := 165.0
	var gap := 12.0
	var x := 42.0
	_make_btn("Use sample", x, by, bw, _on_sample); x += bw + gap
	_make_btn("Load file", x, by, bw, _on_load); x += bw + gap
	_gen_btn = _make_btn("Generate (offline)", x, by, bw, _on_generate_offline); x += bw + gap
	_genai_btn = _make_btn("Generate with AI", x, by, bw, _on_generate_ai); x += bw + gap
	_make_btn("Back", x, by, bw, _on_back)
	_gen_btn.add_theme_color_override("font_color", Color(0.2, 0.95, 0.4))
	_genai_btn.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	_gen_btn.grab_focus()

	_dialog = FileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.filters = PackedStringArray(["*.txt, *.md ; Lesson plan (text)"])
	_dialog.size = Vector2i(720, 480)
	_dialog.file_selected.connect(_on_file_selected)
	add_child(_dialog)

	_http = HTTPRequest.new()
	_http.timeout = 8.0
	_http.request_completed.connect(_on_ai_completed)
	add_child(_http)

func _make_btn(label: String, x: float, y: float, w: float, cb: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.position = Vector2(x, y)
	b.size = Vector2(w, 40)
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(cb)
	add_child(b)
	return b

func _on_sample() -> void:
	var path := "res://tools/sample_lesson_plan.md"
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			_text.text = f.get_as_text()
			f.close()
			_status.text = "Loaded the sample plan."

func _on_load() -> void:
	_dialog.popup_centered()

func _on_file_selected(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f != null:
		_text.text = f.get_as_text()
		f.close()
		_status.text = "Loaded %s" % path.get_file()

func _on_generate_offline() -> void:
	var txt := _text.text.strip_edges()
	if txt.length() < 20:
		_status.text = "Paste or load a lesson plan first (a few lines is enough)."
		return
	_go_preview(LessonImport.plan_to_scenario(txt))

func _on_generate_ai() -> void:
	var txt := _text.text.strip_edges()
	if txt.length() < 20:
		_status.text = "Paste or load a lesson plan first."
		return
	_pending_text = txt
	_status.text = "Contacting AI backend..."
	# Lock both generate paths while the request is in flight so a double-click
	# cannot fire a second request (HTTPRequest would return ERR_BUSY and silently
	# degrade to the offline conversion).
	_gen_btn.disabled = true
	_genai_btn.disabled = true
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := _http.request(ENDPOINT, headers, HTTPClient.METHOD_POST, JSON.stringify({"plan_text": txt}))
	if err != OK:
		_status.text = "Backend unreachable; using offline conversion."
		_go_preview(LessonImport.plan_to_scenario(txt))

func _on_ai_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("roster") and not parsed.has("error"):
			_status.text = "AI scenario ready."
			_go_preview(parsed)
			return
	_status.text = "Backend unavailable; used offline conversion."
	_go_preview(LessonImport.plan_to_scenario(_pending_text))

func _go_preview(scenario: Dictionary) -> void:
	SceneRouter.change_scene("res://scenes/ui/PreviewScenario.tscn", {"scenario": scenario})

func _on_back() -> void:
	SceneRouter.change_scene("res://scenes/ui/Hub.tscn")
