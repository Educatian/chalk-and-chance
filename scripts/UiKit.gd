extends RefCounted
## The v2 UI frame kit (docs/ui-design-plan.md 3.5): three nine-slice frames built from
## the code-generated textures in assets/v2/ui, plus the pixel display face. Each texture
## is already drawn at 2 px per texel, so borders sit on the same grid as the world art.

const BOARD := "res://assets/v2/ui/frame_board.png"
const PAPER := "res://assets/v2/ui/frame_paper.png"
const BTN := "res://assets/v2/ui/button_%s.png"
const PIXEL_FONT := "res://ui/fonts/PixelifySans.ttf"

static var _cache := {}

## Chalkboard frame: HUD bands, dialogue, encounter panels, interrupt cards.
static func board(pad: int = 12) -> StyleBoxTexture:
	return _box(BOARD, 10, pad)

## Paper card: briefings, results, documents, settings.
static func paper(pad: int = 14) -> StyleBoxTexture:
	return _box(PAPER, 8, pad)

## Button face for a state: normal, hover, pressed, disabled, focus (focus is a ring).
static func button(state: String, pad: int = 6) -> StyleBoxTexture:
	return _box(BTN % state, 8, pad)

static func _box(path: String, margin: int, pad: int) -> StyleBoxTexture:
	var key := "%s|%d|%d" % [path, margin, pad]
	if _cache.has(key):
		return _cache[key]
	var sb := StyleBoxTexture.new()
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	sb.texture = t
	sb.texture_margin_left = margin
	sb.texture_margin_top = margin
	sb.texture_margin_right = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	_cache[key] = sb
	return sb

static func pixel_font() -> Font:
	if not _cache.has("font") and ResourceLoader.exists(PIXEL_FONT):
		_cache["font"] = load(PIXEL_FONT)
	return _cache.get("font", null)

## Apply the kit to one button (all five states).
static func style_button(b: Button, font_size: int = 14, pad: int = 6) -> void:
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, button(st, pad))
	var f := pixel_font()
	if f != null:
		b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color("14131c"))
	b.add_theme_color_override("font_hover_color", Color("14131c"))
	b.add_theme_color_override("font_pressed_color", Color("5a3a26"))
	b.add_theme_color_override("font_focus_color", Color("14131c"))
	b.add_theme_color_override("font_disabled_color", Color("4a5a72"))

## Panel with a kit frame.
static func panel(kind: String = "board") -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", board() if kind == "board" else paper())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## Dark chalkboard button face (cards, lists, secondary actions with chalk-coloured text).
static func board_button(state: String, pad: int = 8) -> StyleBoxTexture:
	var st := state if state != "focus" else "normal"
	return _box("res://assets/v2/ui/button_board_%s.png" % st, 8, pad)

static func style_board_button(b: Button, font_size: int = -1, pad: int = 8) -> void:
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, board_button(st, pad))
	b.add_theme_stylebox_override("focus", button("focus"))
	var f := pixel_font()
	if f != null:
		b.add_theme_font_override("font", f)
	if font_size > 0:
		b.add_theme_font_size_override("font_size", font_size)

## Push the kit into the project theme so every screen that relies on theme defaults
## (Panel, PanelContainer, Button) gets the v2 frames. Called once at boot (Juice._ready).
static func apply_to_theme() -> void:
	var theme := ThemeDB.get_project_theme()
	if theme == null or not ResourceLoader.exists(BOARD):
		return
	theme.set_stylebox(&"panel", &"Panel", board())
	theme.set_stylebox(&"panel", &"PanelContainer", board())
	for st in ["normal", "hover", "pressed", "disabled"]:
		theme.set_stylebox(StringName(st), &"Button", board_button(st))
	theme.set_stylebox(&"focus", &"Button", button("focus"))
	var f := pixel_font()
	if f != null:
		theme.set_font(&"font", &"Button", f)
	theme.set_color(&"font_color", &"Button", Color("f2eedd"))
	theme.set_color(&"font_hover_color", &"Button", Color("ffffff"))
	theme.set_color(&"font_pressed_color", &"Button", Color("b9b7a8"))
	theme.set_color(&"font_focus_color", &"Button", Color("f2eedd"))
	theme.set_color(&"font_disabled_color", &"Button", Color("4a5a72"))

## Teaching-move button: paper face, icon left, full label, one-line hint underneath.
## Authored in 480x270 space (sizes are scaled x2 by PixelUi.scale_tree afterwards).
static func style_move_button(b: Button, font_size: int, icon_path: String, hint: String, hint_size: int) -> void:
	style_button(b, font_size)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb: StyleBoxTexture = (button(st) as StyleBoxTexture).duplicate()
		sb.content_margin_left = 10
		sb.content_margin_bottom = 22
		sb.content_margin_top = 4
		b.add_theme_stylebox_override(st, sb)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if ResourceLoader.exists(icon_path):
		# Built-in icon slot: drawn at the texture's 16 px, label placed after it.
		b.icon = load(icon_path)
		b.expand_icon = false
		b.add_theme_constant_override("h_separation", 6)
	if hint != "":
		if not b.is_inside_tree():
			# Labels measured outside the tree use the fallback font; build the hint on entry.
			b.tree_entered.connect(func(): _add_move_hint(b, hint, hint_size), CONNECT_ONE_SHOT)
		else:
			_add_move_hint(b, hint, hint_size)

static func _add_move_hint(b: Button, hint: String, hint_size: int) -> void:
	if true:
		var h := Label.new()
		h.name = "MoveHint"
		h.text = hint
		h.position = Vector2(5, 21)
		h.clip_text = true
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_font_size_override("font_size", hint_size + GameState.ui_font_delta())
		h.add_theme_color_override("font_color", Color("5a3a26"))
		b.add_child(h)
		h.size = Vector2(84, 10)   # after the font override, or the default font height wins

## Shared setting for encounter-family screens (480x270 authored space): the dimmed
## classroom backdrop, a framed title strip and chalkboard panels behind content regions.
## Call first in _build_ui so everything else draws on top.
static func add_scene_frame(layer: Control, title_rect: Rect2, panels: Array) -> void:
	var path := "res://assets/v2/ui/encounter_backdrop_modern.png"
	if ResourceLoader.exists(path):
		var bd := TextureRect.new()
		bd.texture = load(path)
		bd.size = Vector2(480, 270)
		bd.stretch_mode = TextureRect.STRETCH_SCALE
		bd.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bd.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bd.modulate = Color(0.55, 0.57, 0.62)
		bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(bd)
	for r in [title_rect] + panels:
		var p := panel("board")
		p.position = r.position
		p.size = r.size
		layer.add_child(p)

## Prefer the palette-remapped v2 portrait when one exists.
static func portrait_path(path: String) -> String:
	if path.contains("/assets/portraits/"):
		var v2 := path.replace("/assets/portraits/", "/assets/v2/portraits/")
		if ResourceLoader.exists(v2):
			return v2
	return path
