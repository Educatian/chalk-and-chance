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
static func style_button(b: Button, font_size: int = 14) -> void:
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, button(st))
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
