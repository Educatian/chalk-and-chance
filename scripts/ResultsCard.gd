extends RefCounted
## One results/debrief card for encounters and classroom periods, in 960x540 design space:
## grade + one-sentence verdict, three labelled score parts (each with its cause),
## rewards as icons, the moments that decided it, one next target, then the actions.
## Celebration scales with the grade: S/A/B get the completion burst, C/D stay calm.

const UiKit = preload("res://scripts/UiKit.gd")
const UiText = preload("res://scripts/UiText.gd")
const CompletionFx = preload("res://scenes/encounter/CompletionFx.gd")
const Art = preload("res://scripts/Art.gd")

const RECT := Rect2(150, 30, 660, 480)
const ICONS := {
	"right": "res://assets/v2/ui/icon_ok.png",
	"early": "res://assets/v2/ui/icon_early.png",
	"wrong": "res://assets/v2/ui/icon_notyet.png",
	"neutral": "res://assets/v2/ui/icon_neutral.png",
}
const INK := Color("f2eedd")
const MUTED := Color("aab6c8")
const NEXT := Color("9fe3b0")

## data: title, rank, verdict, parts [{label, frac, value, cause}] (3), rewards {badge, caption,
## none, level_up, level_after, items}, moments [{kind, text}], next, buttons [{label, cb, primary}].
static func build(parent: Node, data: Dictionary) -> Control:
	var root := Control.new()
	root.name = "ResultsCard"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(root)
	var rank := str(data.get("rank", "-"))
	var celebrate := rank in ["S", "A", "B"]
	var r := RECT
	if celebrate:
		CompletionFx.add_completion_burst(root, r, true, rank, false)
	else:
		var dim := ColorRect.new()
		dim.color = Color(0.02, 0.03, 0.07, 0.62)
		dim.size = UiText.DESIGN
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(dim)
	var panel := UiKit.panel("board")
	panel.position = r.position
	panel.size = r.size
	root.add_child(panel)

	# Grade disc + verdict.
	var x0 := r.position.x + 24.0
	var y := r.position.y + 22.0
	var disc := Label.new()
	disc.name = "Grade"
	disc.text = rank
	disc.position = Vector2(x0, y)
	disc.size = Vector2(64, 64)
	disc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	disc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Smooth face: in the pixel face D reads as 0 at this size.
	disc.add_theme_font_size_override("font_size", 40)
	var rc := grade_color(rank)
	disc.add_theme_color_override("font_color", rc)
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color(0.06, 0.07, 0.13)
	ring.border_color = rc
	ring.set_border_width_all(3)
	ring.set_corner_radius_all(32)
	disc.add_theme_stylebox_override("normal", ring)
	root.add_child(disc)
	_label(root, str(data.get("title", "")), Vector2(x0 + 80, y), Vector2(530, 18), UiText.fs(12), MUTED)
	_label(root, str(data.get("verdict", "")), Vector2(x0 + 80, y + 18), Vector2(530, 48), UiText.fs(18), INK, true)

	# Three score parts: label + value, bar, cause.
	y = r.position.y + 104.0
	var parts: Array = data.get("parts", [])
	var cw := (r.size.x - 48.0 - 24.0) / 3.0
	for i in range(mini(3, parts.size())):
		var p: Dictionary = parts[i]
		var px := x0 + i * (cw + 12.0)
		_label(root, str(p.get("label", "")), Vector2(px, y), Vector2(cw, 16), UiText.fs(14), INK)
		var v := _label(root, str(p.get("value", "")), Vector2(px, y), Vector2(cw, 16), UiText.fs(14), INK)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var frac := clampf(float(p.get("frac", 0.0)), 0.0, 1.0)
		var bg := ColorRect.new()
		bg.position = Vector2(px, y + 22)
		bg.size = Vector2(cw, 8)
		bg.color = Color(0, 0, 0, 0.45)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bg)
		var fill := ColorRect.new()
		fill.position = bg.position
		fill.size = Vector2(maxf(2.0, cw * frac), 8)
		fill.color = Color("5fbf6a") if frac >= 0.66 else (Color("e0b54a") if frac >= 0.4 else Color("ec8a6e"))
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(fill)
		_label(root, str(p.get("cause", "")), Vector2(px, y + 34), Vector2(cw, 34), UiText.fs(12), MUTED, true)

	# Moments that decided it (A4): what you did -> how they reacted -> why it mattered.
	y = r.position.y + 182.0
	_label(root, "Moments that decided it", Vector2(x0, y), Vector2(400, 16), UiText.fs(12), MUTED)
	y += 20.0
	var moments: Array = data.get("moments", [])
	for m in moments.slice(0, 3):
		var ic := TextureRect.new()
		ic.texture = Art.tex(str(ICONS.get(str(m.get("kind", "neutral")), ICONS["neutral"])))
		ic.position = Vector2(x0, y + 2)
		ic.size = Vector2(16, 16)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(ic)
		ic.size = Vector2(16, 16)
		_label(root, str(m.get("text", "")), Vector2(x0 + 24, y), Vector2(r.size.x - 72, 38), UiText.fs(14), INK, true)
		y += 44.0
	if moments.is_empty():
		_label(root, "No turning points yet: the period ended before a move landed.", Vector2(x0 + 24, y), Vector2(r.size.x - 72, 20), UiText.fs(14), MUTED)

	# One next target.
	y = r.position.y + 336.0
	_label(root, "Next time", Vector2(x0, y), Vector2(120, 16), UiText.fs(12), NEXT)
	_label(root, str(data.get("next", "")), Vector2(x0 + 80, y), Vector2(r.size.x - 128, 36), UiText.fs(14), NEXT, true)

	# Rewards as icons. They come last and say what they are for (finishing), so a low grade beside a
	# new badge does not read as a mixed message.
	y = r.position.y + 384.0
	var rw: Dictionary = data.get("rewards", {})
	_label(root, str(rw.get("caption", "Earned")), Vector2(x0, y + 6), Vector2(150, 16), UiText.fs(12), MUTED)
	var rx := x0 + 156.0
	var badge := str(rw.get("badge", ""))
	if badge != "":
		rx = _icon_chip(root, "res://assets/ui/badge_%s.png" % badge, badge.capitalize() + " badge", Vector2(rx, y))
	if bool(rw.get("level_up", false)):
		rx = _icon_chip(root, "", "Lv %d  +1 upgrade" % int(rw.get("level_after", 0)), Vector2(rx, y))
	var items = rw.get("items", {})
	if typeof(items) == TYPE_DICTIONARY:
		for id in items.keys():
			if int(items[id]) > 0 and rx < r.end.x - 120:
				rx = _icon_chip(root, Items.icon_for(str(id)), "%s x%d" % [Items.short_name_for(str(id)), int(items[id])], Vector2(rx, y))
	for e in rw.get("extra", []):
		rx = _icon_chip(root, ICONS["right"], str(e), Vector2(rx, y))
	if rx == x0 + 156.0:
		_label(root, str(rw.get("none", "Nothing this time.")), Vector2(rx, y + 6), Vector2(r.end.x - rx - 24, 16), UiText.fs(12), MUTED)

	# Actions: secondary on the left, the primary at normal size on the right.
	var btns: Array = data.get("buttons", [])
	var bx := r.end.x - 24.0
	var focus: Button = null
	for i in range(btns.size() - 1, -1, -1):
		var bd: Dictionary = btns[i]
		var b := Button.new()
		b.text = str(bd.get("label", "OK"))
		var primary := bool(bd.get("primary", false))
		if primary:
			UiKit.style_button(b, UiText.fs(14))
			focus = b
		else:
			UiKit.style_board_button(b, UiText.fs(14))
		b.pressed.connect(bd["cb"])
		root.add_child(b)
		var w := maxf(200.0 if primary else 190.0, b.get_combined_minimum_size().x)
		bx -= w
		b.position = Vector2(bx, r.end.y - 46.0)
		b.size = Vector2(w, 36)
		bx -= 10.0
	if focus != null:
		focus.grab_focus.call_deferred()
	return root

static func grade_color(rank: String) -> Color:
	match rank:
		"S":
			return Color(1.0, 0.84, 0.30)
		"A":
			return Color(0.40, 0.95, 0.72)
		"B":
			return Color(0.50, 0.78, 1.0)
	return Color("c9d2e0")   # C/D: calm slate, never alarm red

static func _icon_chip(root: Control, icon: String, text: String, pos: Vector2) -> float:
	var x := pos.x
	var t: Texture2D = Art.tex(icon) if icon != "" else null
	if t != null:
		var ic := TextureRect.new()
		ic.texture = t
		ic.position = Vector2(x, pos.y)
		ic.size = Vector2(28, 28)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(ic)
		ic.size = Vector2(28, 28)
		x += 32.0
	var w := float(text.length()) * 7.5 + 8.0
	_label(root, text, Vector2(x, pos.y + 6), Vector2(w, 16), UiText.fs(14), INK)
	return x + w + 16.0

static func _label(root: Control, text: String, pos: Vector2, size: Vector2, fs: int, color: Color, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(size.x, 0)   # wrap width fixed before the height resolves
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	root.add_child(l)
	l.size = size
	return l

## Verdict sentence for a grade; `weak` names the part that held it back.
static func verdict(rank: String, weak: String) -> String:
	match rank:
		"S":
			return "Excellent work: every part of this held up."
		"A":
			return "Strong session. Small gains left in %s." % weak
		"B":
			return "Solid. %s held the score back a little." % weak.capitalize()
		"C":
			return "You got there, with detours. %s is the part to practise." % weak.capitalize()
	return "%s held the score down. That is the place to start." % weak.capitalize()

## Classroom grade from the share of the best possible period score. Honest caps: a
## missed objective means no badge, so at most C; under half the objectives met is D.
static func classroom_rank(frac: float, stars: int, n: int) -> String:
	var rank := "S" if frac >= 0.9 else ("A" if frac >= 0.8 else ("B" if frac >= 0.65 else ("C" if frac >= 0.5 else "D")))
	if n > 0 and stars * 2 < n:
		return "D"
	if stars < n and rank in ["S", "A", "B"]:
		return "C"
	return rank

## Index of the weakest part (lowest frac); ties go to the first.
static func weakest(parts: Array) -> int:
	var wi := 0
	for i in range(parts.size()):
		if float(parts[i].get("frac", 0.0)) < float(parts[wi].get("frac", 0.0)):
			wi = i
	return wi
