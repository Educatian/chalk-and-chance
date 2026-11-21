extends Node
## Shared motion/feedback vocabulary ("juice") so every screen moves the same way:
## animated bars, floating deltas, punch, pop-in, shake, flash, and turn beats.
## Accessibility floor: the existing "reduced_motion" setting turns off movement,
## screen shake and flashes everywhere that goes through here (values still update).
## Built from Tweens on Controls only (no shaders), so it is cheap on the web build.

const TurnBeat = preload("res://scripts/TurnBeat.gd")

var _beats: Array = []   # [{owner: Node, beat: TurnBeat}]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	preload("res://scripts/UiKit.gd").apply_to_theme()   # v2 frames for every themed Panel/Button

func motion_ok() -> bool:
	return not bool(GameState.get_setting("reduced_motion", false))

# --- turn beats ------------------------------------------------------------------

## Start a beat owned by `owner`. If the owner is freed, its beat is dropped silently.
func play_beat(owner: Node, beat: RefCounted) -> void:
	_beats.append({"owner": owner, "beat": beat})
	beat.advance(0.0)
	_prune()

func has_beat(owner: Node) -> bool:
	for b in _beats:
		if b["owner"] == owner and not b["beat"].is_done():
			return true
	return false

## Finish every running beat of `owner` immediately. Returns true if any was running.
func skip_beats(owner: Node) -> bool:
	var any := false
	for b in _beats.duplicate():
		if b["owner"] == owner and not b["beat"].is_done():
			any = true
			b["beat"].finish()
	_prune()
	return any

func _process(delta: float) -> void:
	if _beats.is_empty():
		return
	for b in _beats.duplicate():
		if is_instance_valid(b["owner"]) and b["owner"].is_inside_tree():
			b["beat"].advance(delta)
	_prune()

func _prune() -> void:
	_beats = _beats.filter(func(b): return is_instance_valid(b["owner"]) and not b["beat"].is_done())

# --- motion helpers ----------------------------------------------------------------

## Animate a fill rect to `target` size (bars ease toward their new value instead of
## jumping). Snaps when motion is reduced or the node is not in the tree yet.
func bar_to(fill: Control, target: Vector2, dur: float = 0.35, delay: float = 0.0) -> void:
	if fill == null or not is_instance_valid(fill):
		return
	var old: Tween = fill.get_meta("juice_bar_tw") if fill.has_meta("juice_bar_tw") else null
	if old != null and old.is_valid():
		old.kill()
	if not motion_ok() or not fill.is_inside_tree() or fill.size.is_equal_approx(target):
		fill.size = target
		return
	var tw := fill.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(fill, "size", target, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	fill.set_meta("juice_bar_tw", tw)

## A short label that rises and fades (meter deltas, "+12"). Reduced motion: it stays
## put and simply fades, so the information is still shown.
func float_text(parent: Node, text: String, pos: Vector2, color: Color, font_size: int = 14) -> Label:
	if parent == null or not is_instance_valid(parent):
		return null
	var l := Label.new()
	l.text = text
	l.position = pos
	l.z_index = 20
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.08))
	l.add_theme_constant_override("outline_size", maxi(2, font_size / 5))
	parent.add_child(l)
	var tw := l.create_tween()
	if motion_ok():
		tw.set_parallel(true)
		tw.tween_property(l, "position:y", pos.y - font_size * 1.2, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "modulate:a", 0.0, 0.45).set_delay(0.55)
		tw.chain().tween_callback(l.queue_free)
	else:
		tw.tween_interval(1.0)
		tw.tween_property(l, "modulate:a", 0.0, 0.3)
		tw.tween_callback(l.queue_free)
	return l

## Quick scale punch around the node's centre (a "this changed" accent).
func punch(node: Control, amount: float = 0.08, dur: float = 0.22) -> void:
	if node == null or not is_instance_valid(node) or not motion_ok():
		return
	var old: Tween = node.get_meta("juice_punch_tw") if node.has_meta("juice_punch_tw") else null
	if old != null and old.is_valid():
		old.kill()
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE * (1.0 + amount)
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	node.set_meta("juice_punch_tw", tw)

## Modal/panel entrance: fade + slight scale up. Skipped for reduced motion.
func pop_in(node: Control, dur: float = 0.18, from_scale: float = 0.96) -> void:
	if node == null or not is_instance_valid(node) or not motion_ok():
		return
	node.pivot_offset = node.size * 0.5 if node.size != Vector2.ZERO else node.get_viewport_rect().size * 0.5
	node.modulate.a = 0.0
	node.scale = Vector2.ONE * from_scale
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "modulate:a", 1.0, dur * 0.8)
	tw.tween_property(node, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Small positional shake. Off under reduced motion (accessibility floor).
func shake(node: Control, amount: float = 4.0, steps: int = 5) -> void:
	if node == null or not is_instance_valid(node) or not motion_ok():
		return
	var base := node.position
	var tw := node.create_tween()
	for i in range(steps):
		var k := 1.0 - float(i) / float(steps)
		tw.tween_property(node, "position", base + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * amount * k, 0.03)
	tw.tween_property(node, "position", base, 0.03)

## Brief colour flash on a CanvasItem. Off under reduced motion (no flashing).
func flash(node: CanvasItem, color: Color, dur: float = 0.28) -> void:
	if node == null or not is_instance_valid(node) or not motion_ok():
		return
	var rest := node.modulate
	node.modulate = color
	var tw := node.create_tween()
	tw.tween_property(node, "modulate", rest, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# --- outcome chip (turn result) ------------------------------------------------------

## A small pill label ("LANDED" / "TOO EARLY" / "NOT YET") placed at the start of a
## result line. Hidden until the first outcome. Built in authored space, like its siblings.
func make_outcome_chip(parent: Node, pos: Vector2, size: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.name = "OutcomeChip"
	l.position = pos
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size + GameState.ui_font_delta())
	l.add_theme_color_override("font_color", Color(0.05, 0.07, 0.12))
	l.add_theme_constant_override("line_spacing", -2)
	l.clip_text = true
	l.visible = false
	parent.add_child(l)
	# Size last: a Label clamps its size to its minimum, which depends on the font
	# override set above (setting it first locked the chip to the default font height).
	l.size = size
	return l

## Show the verdict colour/label on a chip and slide its result line over to make room.
## Only a landed move gets the pop; a miss is shown plainly, never celebrated.
func show_outcome(chip: Label, kind: String) -> void:
	if chip == null or not is_instance_valid(chip):
		return
	chip.text = TurnBeat.label(kind)
	var sb := StyleBoxFlat.new()
	sb.bg_color = TurnBeat.color(kind)
	sb.set_corner_radius_all(maxi(2, int(chip.size.y * 0.3)))
	sb.set_content_margin_all(0)
	chip.add_theme_stylebox_override("normal", sb)
	chip.visible = true
	# Lines that start where the chip sits slide right to make room (result, coach...).
	var lines: Array = chip.get_meta("shift_labels") if chip.has_meta("shift_labels") else []
	for line in lines:
		if line == null or not is_instance_valid(line):
			continue
		if not line.has_meta("orig_right"):
			line.set_meta("orig_right", line.position.x + line.size.x)
		line.position.x = chip.position.x + chip.size.x + chip.size.y * 0.6
		line.size.x = float(line.get_meta("orig_right")) - line.position.x
	if kind == TurnBeat.RIGHT:
		punch(chip, 0.18)
