extends Control
const UiText = preload("res://scripts/UiText.gd")
## Chapter intro cinematic played before every mission. Data: data/narrative/chapters.json.
## Letterboxed, one composed frame per beat (tools/art/cinematic_frames.py: the title, each
## story beat, the outro; both classroom looks) crossfading as the story moves -> chapter
## title on a solid band -> dialogue and narration on the same band, never over a face ->
## hands off to the mission scene.
## Click / Space / Enter advances; Esc or the Skip button jumps straight to the mission.

const Art = preload("res://scripts/Art.gd")
const Narrative = preload("res://scripts/Narrative.gd")
const HubUi = preload("res://scenes/ui/HubUi.gd")
const PIXEL_FONT := "res://ui/fonts/Galmuri11-Bold.ttf"
const BAR_H := 58.0
const CHARS_PER_SEC := 48.0

var _cfg: Dictionary = {}
var _chapter: Dictionary = {}
var _next_path := ""
var _next_data: Dictionary = {}
var _beats: Array = []
var _beat := -1
var _typing := false
var _finished := false
var _reduced := false
var _vp := Vector2(960, 540)
var _outro := false
var _won := true
var _end_card_up := false

var _backdrop: TextureRect
var _backdrop_next: TextureRect   # crossfade target for the next beat's frame
var _shade: ColorRect
var _top_bar: ColorRect
var _bottom_bar: ColorRect
var _card: Control
var _box: Control
var _portrait: TextureRect
var _portrait_frame: Panel
var _name: Label
var _text: RichTextLabel
var _caption: RichTextLabel
var _hint: Label
var _type_tween: Tween

func setup(data: Dictionary) -> void:
	_cfg = data.get("scenario", {})
	_next_path = str(data.get("next_path", "res://scenes/ui/Hub.tscn"))
	_next_data = data.get("next_data", {})
	_chapter = Narrative.chapter(str(_cfg.get("id", "")))
	_outro = str(data.get("mode", "intro")) == "outro"
	_won = bool(data.get("won", true))
	if _outro:
		var line := Narrative.outro(str(_cfg.get("id", "")), _won)
		_beats = [line] if not line.is_empty() else []
	else:
		_beats = _chapter.get("intro", [])
	_reduced = bool(GameState.get_setting("reduced_motion", false))
	_vp = get_viewport_rect().size
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	Music.play("tension" if str(_cfg.get("mode", "")) == "gym" and not _outro else "cinematic")
	_run()

# --- build -----------------------------------------------------------------------

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_backdrop = _frame_rect()
	_backdrop.texture = _frame_tex("outro" if _outro else "title")
	_backdrop.modulate = Color(1, 1, 1, 0)
	add_child(_backdrop)
	_backdrop_next = _frame_rect()
	_backdrop_next.modulate = Color(1, 1, 1, 0)
	add_child(_backdrop_next)

	# The frames are composed with the text band in mind, so only a light shade is needed.
	_shade = ColorRect.new()
	_shade.color = Color(0.02, 0.03, 0.07, 0.12)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	add_child(_vignette())

	_top_bar = _bar(Vector2(0, -BAR_H))
	_bottom_bar = _bar(Vector2(0, _vp.y))
	add_child(_top_bar)
	add_child(_bottom_bar)

	_card = _build_card()
	add_child(_card)
	_box = _build_dialogue_box()
	add_child(_box)

	_caption = RichTextLabel.new()
	_caption.bbcode_enabled = true
	_caption.fit_content = true
	_caption.scroll_active = false
	_caption.position = Vector2(120, _vp.y * 0.5 - 30)
	_caption.size = Vector2(_vp.x - 240, 60)
	_caption.add_theme_font_size_override("normal_font_size", UiText.fs(17))
	_caption.add_theme_font_size_override("italics_font_size", UiText.fs(17))
	_caption.add_theme_color_override("default_color", Color(0.93, 0.94, 0.90))
	_caption.add_theme_constant_override("outline_size", 6)
	_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.visible = false
	add_child(_caption)

	_hint = Label.new()
	_hint.text = "Click / Space  »"
	_hint.position = Vector2(_vp.x - 190, _vp.y - 22)
	_hint.size = Vector2(170, 18)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", UiText.fs(10))
	_hint.add_theme_color_override("font_color", Color(0.75, 0.78, 0.86, 0.8))
	_hint.modulate.a = 0.0
	add_child(_hint)

	var skip := Button.new()
	skip.text = "Skip »"
	skip.position = Vector2(_vp.x - 104, 14)
	skip.size = Vector2(88, 28)
	skip.focus_mode = Control.FOCUS_NONE
	skip.add_theme_font_size_override("font_size", UiText.fs(11))
	HubUi.apply_button_style(skip, false)
	skip.pressed.connect(_finish)
	add_child(skip)

func _build_card() -> Control:
	var card := Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.modulate.a = 0.0
	var band_y := _vp.y - BAR_H - 146.0
	var band := Panel.new()
	band.position = Vector2(24, band_y)
	band.size = Vector2(_vp.x - 48, 138)
	var bsb := HubUi.plate_style(Color(0.05, 0.06, 0.12, 0.94), Color(0.98, 0.82, 0.30, 0.85))
	bsb.set_border_width_all(2)
	band.add_theme_stylebox_override("panel", bsb)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(band)
	var kicker := _label("CHAPTER %d  ·  %s" % [int(_chapter.get("chapter", 0)), str(_chapter.get("month", ""))],
		Vector2(0, band_y + 12), Vector2(_vp.x, 20), 12, Color(0.98, 0.82, 0.30))
	kicker.name = "Kicker"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(kicker)
	var title := _label("", Vector2(40, band_y + 34), Vector2(_vp.x - 80, 44), 22, Color(0.98, 0.96, 0.88))
	title.name = "Title"
	title.add_theme_font_override("font", load(PIXEL_FONT))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.07))
	card.add_child(title)
	var region := _label(str(_chapter.get("region", "")).to_upper(), Vector2(0, band_y + 84), Vector2(_vp.x, 18), 11, Color(0.62, 0.88, 0.95))
	region.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(region)
	var mission := _label(str(_cfg.get("title", "")), Vector2(0, band_y + 106), Vector2(_vp.x, 18), 12, Color(0.80, 0.84, 0.92))
	mission.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(mission)

	# Today's class is in the title frame itself, seated, at full size.
	return card

func _build_dialogue_box() -> Control:
	var box := Control.new()
	box.position = Vector2(0, _vp.y - 146)
	box.size = Vector2(_vp.x, 146)
	box.modulate.a = 0.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var plate := Panel.new()
	plate.position = Vector2(24, 18)
	plate.size = Vector2(_vp.x - 48, 98)
	var sb := HubUi.plate_style(Color(0.05, 0.06, 0.12, 0.93), Color(0.98, 0.82, 0.30, 0.85))
	sb.set_border_width_all(2)
	plate.add_theme_stylebox_override("panel", sb)
	box.add_child(plate)

	_portrait_frame = Panel.new()
	_portrait_frame.position = Vector2(40, -14)
	_portrait_frame.size = Vector2(120, 120)
	_portrait_frame.add_theme_stylebox_override("panel", HubUi.plate_style(Color(0.08, 0.10, 0.20), Color(0.98, 0.82, 0.30)))
	box.add_child(_portrait_frame)
	_portrait = TextureRect.new()
	_portrait.position = Vector2(4, 4)
	_portrait.size = Vector2(112, 112)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_frame.add_child(_portrait)

	_name = _label("", Vector2(178, 28), Vector2(400, 20), 13, Color.WHITE)
	_name.add_theme_font_override("font", load(PIXEL_FONT))
	box.add_child(_name)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.position = Vector2(178, 56)
	_text.size = Vector2(_vp.x - 230, 70)
	_text.add_theme_font_size_override("normal_font_size", UiText.fs(15))
	_text.add_theme_font_size_override("italics_font_size", UiText.fs(15))
	_text.add_theme_color_override("default_color", Color(0.94, 0.95, 0.92))
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_text)
	return box

# --- sequence --------------------------------------------------------------------

func _run() -> void:
	# Letterbox in, backdrop fades up and starts its slow push.
	var t := create_tween().set_parallel(true)
	t.tween_property(_top_bar, "position:y", 0.0, 0.6 if not _reduced else 0.01).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_bottom_bar, "position:y", _vp.y - BAR_H, 0.6 if not _reduced else 0.01).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_backdrop, "modulate:a", 1.0, 1.2)
	_drift(_backdrop)
	Sfx.play("whoosh", -4.0)
	await get_tree().create_timer(0.5).timeout
	if _finished:
		return
	if not _outro:
		await _play_card()
		if _finished:
			return
	_next_beat()

func _play_card() -> void:
	var title: Label = _card.get_node("Title")
	var full := str(_chapter.get("title", _cfg.get("title", "")))
	var t := create_tween()
	t.tween_property(_card, "modulate:a", 1.0, 0.35)
	await t.finished
	# Typewriter title with blips.
	for i in range(full.length() + 1):
		if _finished:
			return
		title.text = full.substr(0, i)
		if i > 0 and full[i - 1] != " ":
			Sfx.blip("type")
		if not _reduced:
			await get_tree().create_timer(0.045).timeout
	await get_tree().create_timer(1.8 if not _reduced else 0.6).timeout
	if _finished:
		return
	var out := create_tween()
	out.tween_property(_card, "modulate:a", 0.0, 0.4)
	await out.finished

func _next_beat() -> void:
	_beat += 1
	if _beat >= _beats.size():
		if _outro and not _end_card_up:
			_show_end_card()
		else:
			_finish()
		return
	var beat: Dictionary = _beats[_beat]
	var who := str(beat.get("speaker", "narrator"))
	var line := Narrative.line_text(beat, _cfg)
	_show_frame(_frame_tex("outro" if _outro else str(_beat)))
	_caption.visible = false
	# Narration uses the same band as dialogue: no name, no portrait, italic.
	var info: Dictionary = {"name": "", "color": Color.WHITE, "texture": null} if who == "narrator" \
		else Narrative.speaker(who, _cfg, str(beat.get("mood", "neutral")))
	var was_hidden := _box.modulate.a < 0.5
	if was_hidden:
		var bt := create_tween()
		bt.tween_property(_box, "modulate:a", 1.0, 0.25)
	_name.text = str(info["name"])
	_name.add_theme_color_override("font_color", info["color"])
	var tex: Texture2D = info["texture"]
	_portrait_frame.visible = tex != null
	var text_x := 178.0 if tex != null else 48.0
	_name.position.x = text_x
	_text.position.x = text_x
	_text.size.x = _vp.x - text_x - 52.0
	if tex != null:
		var changed := _portrait.texture != tex
		_portrait.texture = tex
		if changed and not _reduced:
			_portrait_frame.position.x = 16
			_portrait_frame.modulate.a = 0.0
			var pt := create_tween().set_parallel(true)
			pt.tween_property(_portrait_frame, "position:x", 40.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			pt.tween_property(_portrait_frame, "modulate:a", 1.0, 0.16)
	var body := ("[i]%s[/i]" % line) if who == "you" or who == "narrator" else line
	_type_into(_text, body, who)

func _show_caption(line: String) -> void:
	if _box.modulate.a > 0.0:
		create_tween().tween_property(_box, "modulate:a", 0.0, 0.2)
	_caption.visible = true
	_caption.text = "[center][i]%s[/i][/center]" % line
	_caption.modulate.a = 0.0
	_type_into(_caption, _caption.text, "narrator")
	create_tween().tween_property(_caption, "modulate:a", 1.0, 0.3)

func _type_into(rt: RichTextLabel, bbcode: String, who: String) -> void:
	rt.text = bbcode
	_hint.modulate.a = 0.0
	var instant := _reduced or str(GameState.get_setting("text_reveal", "typewriter")) == "instant"
	var n := rt.get_total_character_count()
	if instant or n == 0:
		rt.visible_characters = -1
		_done_typing()
		return
	rt.visible_characters = 0
	_typing = true
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	_type_tween = create_tween()
	var last := [0]
	_type_tween.tween_method(func(v: float):
		var c := int(v)
		rt.visible_characters = c
		if c - last[0] >= 2 and who != "narrator":
			last[0] = c
			Sfx.blip("type"),
		0.0, float(n), float(n) / CHARS_PER_SEC)
	_type_tween.tween_callback(_done_typing)

func _done_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	_caption.visible_characters = -1
	var ht := create_tween()
	ht.tween_property(_hint, "modulate:a", 1.0, 0.25)

func _advance() -> void:
	if _finished or _beat < 0:
		return
	if _end_card_up:
		_finish()
		return
	if _typing:
		if _type_tween != null and _type_tween.is_valid():
			_type_tween.kill()
		_done_typing()
		return
	Sfx.play("click", -6.0)
	_next_beat()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	Sfx.play("open")
	var t := create_tween().set_parallel(true)
	t.tween_property(_top_bar, "size:y", _vp.y * 0.5 + 2, 0.35 if not _reduced else 0.01).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(_bottom_bar, "position:y", _vp.y * 0.5 - 2, 0.35 if not _reduced else 0.01).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(_bottom_bar, "size:y", _vp.y * 0.5 + 2, 0.35 if not _reduced else 0.01).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await t.finished
	if not _outro:
		GameState.mark_chapter_seen(str(_cfg.get("id", "")))
	SceneRouter.change_scene(_next_path, _next_data)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish()
	elif event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		_advance()

# --- frames ----------------------------------------------------------------------

func _frame_rect() -> TextureRect:
	var r := TextureRect.new()
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.size = _vp
	r.pivot_offset = _vp * 0.5
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## This beat's composed frame in the current classroom look; a mission without frames
## (an imported lesson) falls back to its room picture.
func _frame_tex(name: String) -> Texture2D:
	var sid := str(_cfg.get("id", ""))
	var kr := bool(GameState.get_setting("korean_classroom", false))
	for suf in (["_kr", ""] if kr else [""]):
		var t: Texture2D = Art.tex("res://assets/v2/cinematic/%s/%s%s.png" % [sid, name, suf])
		if t != null:
			return t
	return Art.tex(Art.scenario_backdrop_path(_cfg))

func _show_frame(tex: Texture2D) -> void:
	if tex == null or tex == _backdrop.texture:
		return
	_backdrop_next.texture = tex
	_backdrop_next.scale = Vector2.ONE
	var t := create_tween()
	t.tween_property(_backdrop_next, "modulate:a", 1.0, 0.01 if _reduced else 0.35)
	t.tween_callback(func():
		_backdrop.texture = tex
		_backdrop.scale = _backdrop_next.scale
		_backdrop_next.modulate.a = 0.0
		_drift(_backdrop))

## A slow, small push on the current frame (the composition holds: 3% over a beat).
func _drift(r: TextureRect) -> void:
	if _reduced:
		return
	r.scale = Vector2.ONE
	create_tween().tween_property(r, "scale", Vector2(1.03, 1.03), 6.0).set_trans(Tween.TRANS_SINE)

## Outro end card: chapter result + a teaser for the next chapter.
func _show_end_card() -> void:
	_end_card_up = true
	create_tween().tween_property(_box, "modulate:a", 0.0, 0.25)
	var card := Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.modulate.a = 0.0
	add_child(card)
	move_child(card, _hint.get_index())
	var n := int(_chapter.get("chapter", 0))
	var head := ("CHAPTER %d COMPLETE" % n) if _won else ("CHAPTER %d  ·  NOT YET" % n)
	var title := _label(head, Vector2(40, 170), Vector2(_vp.x - 80, 40), 22, Color(0.98, 0.84, 0.32) if _won else Color(0.95, 0.62, 0.50))
	title.add_theme_font_override("font", load(PIXEL_FONT))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.07))
	card.add_child(title)
	var sub := _label(str(_chapter.get("title", "")), Vector2(0, 222), Vector2(_vp.x, 20), 14, Color(0.92, 0.93, 0.90))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(sub)
	var teaser_text := "Run it again when you're ready. Vee will be there."
	if _won:
		var nxt := Narrative.next_chapter(n)
		teaser_text = "The school year goes on." if nxt.is_empty() else "NEXT  ·  CHAPTER %d  ·  %s  ·  %s" % [int(nxt.get("chapter", 0)), str(nxt.get("month", "")), str(nxt.get("title", ""))]
	var teaser := _label(teaser_text, Vector2(0, 300), Vector2(_vp.x, 20), 12, Color(0.62, 0.88, 0.95))
	teaser.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(teaser)
	var t := create_tween()
	t.tween_property(card, "modulate:a", 1.0, 0.5)
	if not _reduced:
		title.pivot_offset = title.size * 0.5
		title.scale = Vector2(1.3, 1.3)
		t.parallel().tween_property(title, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("levelup" if _won else "close")
	t.tween_callback(func(): create_tween().tween_property(_hint, "modulate:a", 1.0, 0.25))

# --- helpers ---------------------------------------------------------------------

## Backdrop art ships with a flat navy frame; crop it so the Ken Burns push is all picture.
func _trim_border(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var edge := img.get_pixel(0, h / 2)
	var left := 0
	while left < w / 4 and img.get_pixel(left, h / 2).is_equal_approx(edge):
		left += 1
	var right := w - 1
	while right > w * 3 / 4 and img.get_pixel(right, h / 2).is_equal_approx(edge):
		right -= 1
	var top := 0
	while top < h / 4 and img.get_pixel(w / 2, top).is_equal_approx(edge):
		top += 1
	var bottom := h - 1
	while bottom > h * 3 / 4 and img.get_pixel(w / 2, bottom).is_equal_approx(edge):
		bottom -= 1
	if left == 0 and top == 0 and right == w - 1 and bottom == h - 1:
		return tex
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(left + 2, top + 2, right - left - 3, bottom - top - 3)
	return at

func _bar(pos: Vector2) -> ColorRect:
	var b := ColorRect.new()
	b.color = Color.BLACK
	b.position = pos
	b.size = Vector2(_vp.x, BAR_H)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

func _label(text: String, pos: Vector2, size: Vector2, fs: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.add_theme_font_size_override("font_size", UiText.fs(fs))
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _vignette() -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 0.75))
	g.add_point(0.55, Color(0, 0, 0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 1.05)
	gt.width = 256
	gt.height = 144
	var v := TextureRect.new()
	v.texture = gt
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v
