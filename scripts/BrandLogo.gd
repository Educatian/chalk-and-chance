extends Control
## The Chalk & Chance logo (think ring + wordmark), drawn from the 1x brand masters and
## enlarged by a whole number. animate(): the ring fills to three-quarters with a tick,
## then the wordmark and underline reveal. Any press skips to the end; reduced motion
## shows the final state at once. Masters: tools/art/brand_masters.py -> assets/brand/anim.

const FRAMES := 9            # ring_00..ring_09: the resting logo is three-quarters full
const DIR := "res://assets/brand/anim/"

var scale_k := 3
var _ring: TextureRect
var _word: TextureRect
var _tw: Tween
var done := false
var _cb := Callable()

func _init(k: int = 3) -> void:
	scale_k = k

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring = _tex(DIR + "ring_%02d.png" % FRAMES)
	_word = _tex(DIR + "wordmark.png")
	add_child(_ring)
	add_child(_word)
	var rs := _ring.texture.get_size() * scale_k
	var ws := _word.texture.get_size() * scale_k
	_ring.size = rs
	_word.position = Vector2(rs.x + 5 * scale_k, (rs.y - ws.y) * 0.5 + scale_k)
	_word.size = ws
	custom_minimum_size = Vector2(_word.position.x + ws.x, rs.y)
	size = custom_minimum_size

func _tex(path: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## Title intro: about 1.2 s. Calls on_done when finished or skipped.
func animate(on_done: Callable = Callable()) -> void:
	_cb = on_done
	if not Juice.motion_ok():
		_finish(on_done)
		return
	_ring.texture = load(DIR + "ring_00.png")
	_word.modulate.a = 0.0
	var home_x := _word.position.x
	_word.position.x = home_x - 4.0 * scale_k
	_tw = create_tween()
	_tw.tween_interval(0.15)
	for i in range(1, FRAMES + 1):
		var path := DIR + "ring_%02d.png" % i
		_tw.tween_callback(func(): _ring.texture = load(path))
		_tw.tween_interval(0.07)
	_tw.tween_callback(func(): Sfx.play("tick"))
	_tw.tween_property(_word, "modulate:a", 1.0, 0.25)
	_tw.parallel().tween_property(_word, "position:x", home_x, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tw.tween_callback(func(): _finish(on_done))

func _finish(on_done: Callable) -> void:
	if done:
		return
	done = true
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_ring.texture = load(DIR + "ring_%02d.png" % FRAMES)
	_word.modulate.a = 1.0
	_word.position.x = _ring.size.x + 5 * scale_k
	if on_done.is_valid():
		on_done.call()

## Any press during the intro skips it.
func skip() -> void:
	if not done and _tw != null:
		_finish(_cb)
