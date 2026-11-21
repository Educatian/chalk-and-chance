extends Control
## B1: the student's think time drawn as a large ring around their portrait.
## THINK fills while they think (warm), LAND is the short window after they answer (cool),
## READY is the go cue (green). shatter() breaks the ring apart when the teacher cuts in.

enum { HIDDEN, THINK, LAND, READY }

const COL_TRACK := Color(0, 0, 0, 0.45)
const COL_THINK := Color("ffd34e")
const COL_LAND := Color("7cc4ff")
const COL_READY := Color("5fdc72")

var mode := HIDDEN
var frac := 0.0
var _burst := -1.0   # >= 0 while the shatter animation runs
var _caption: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 18)
	_caption.add_theme_color_override("font_color", Color.WHITE)
	_caption.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.08))
	_caption.add_theme_constant_override("outline_size", 6)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	_caption.position = Vector2(0, 8)
	_caption.size = Vector2(size.x, 24)

func show_state(m: int, f: float, caption: String) -> void:
	if m != mode and m == READY:
		Juice.punch(self, 0.08)
	mode = m
	frac = clampf(f, 0.0, 1.0)
	if _burst < 0.0:   # keep "cut off" up while the ring breaks
		_caption.text = caption
		_caption.add_theme_color_override("font_color", _col())
	visible = m != HIDDEN or _burst >= 0.0
	queue_redraw()

func shatter() -> void:
	mode = HIDDEN
	_caption.text = tr("cut off")
	_caption.add_theme_color_override("font_color", Color("ff7a66"))
	visible = true
	_burst = 0.0
	var tw := create_tween()
	tw.tween_method(func(v: float):
		_burst = v
		queue_redraw(), 0.0, 1.0, 0.6 if Juice.motion_ok() else 0.05)
	tw.tween_interval(0.5)
	tw.tween_callback(func():
		_burst = -1.0
		visible = mode != HIDDEN
		queue_redraw())

func _col() -> Color:
	match mode:
		LAND:
			return COL_LAND
		READY:
			return COL_READY
	return COL_THINK

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 10.0
	var w := 10.0
	if _burst >= 0.0:
		# The thought breaks: ring segments fly outward and fade.
		for i in range(10):
			var a0 := TAU * float(i) / 10.0 - PI / 2.0
			var dir := Vector2.from_angle(a0 + TAU / 20.0)
			var col := Color("ff7a66", 1.0 - _burst)
			draw_arc(c + dir * 40.0 * _burst, r, a0, a0 + TAU / 10.0 * 0.75, 6, col, w)
		return
	if mode == HIDDEN:
		return
	draw_arc(c, r, 0.0, TAU, 64, COL_TRACK, w + 4.0)
	if frac > 0.0:
		draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * frac, 64, _col(), w)
