extends RefCounted
## One place for text sizes and screen fitting.
##
## Unscaled screens (classroom HUD, overlays) use Theme type variations defined in
## ui/theme.tres: set `label.theme_type_variation = UiText.HUD` instead of per-label
## font overrides. apply_text_scale() pushes the "Large text" setting into those
## variations at runtime, so one setting resizes every styled label.
##
## Encounter-family screens are authored at 480x270 and scaled x2 by PixelUi.scale_tree,
## which only scales explicit overrides; they keep overrides but take the size from the
## S_* tokens below so their scale stays single-sourced too.

const TITLE := &"TitleLabel"
const HEADING := &"HeadingLabel"
const BODY := &"BodyLabel"
const CAPTION := &"CaptionLabel"
const HUD := &"HudLabel"
const HUD_VALUE := &"HudValueLabel"
const NAME := &"NameTagLabel"
const BODY_SMALL_ON_BOARD := &"BoardBodyLabel"

## Label styles drawn in the pixel display face (titles, HUD labels, numbers, names).
## Small running text (HUD labels, names, hints) stays in the smooth face for legibility.
const PIXEL_STYLES := [&"TitleLabel", &"HeadingLabel", &"HudValueLabel"]
const PIXEL_FONT := "res://ui/fonts/PixelifySans.ttf"

## Base pixel sizes (960x540 design space) for each variation, before "Large text".
const BASE_SIZES := {
	TITLE: 18, HEADING: 15, BODY: 14, CAPTION: 12, HUD: 12, HUD_VALUE: 18, NAME: 12, BODY_SMALL_ON_BOARD: 13,
}

## Tokens for 480x270-authored screens (rendered at x2): 11 -> 22px ... 5 -> 10px.
const S_DISPLAY := 11
const S_TITLE := 9
const S_BODY := 8
const S_CAPTION := 7
const S_MICRO := 6
const S_TINY := 5

## The size every fixed-layout screen is authored for.
const DESIGN := Vector2(960, 540)

static func apply_text_scale() -> void:
	var theme := ThemeDB.get_project_theme()
	if theme == null:
		return
	var delta := GameState.ui_font_delta()
	for v in BASE_SIZES:
		theme.set_font_size(&"font_size", v, int(BASE_SIZES[v]) + delta)
	if ResourceLoader.exists(PIXEL_FONT):
		var f: Font = load(PIXEL_FONT)
		for v in PIXEL_STYLES:
			theme.set_font(&"font", v, f)

static func style(label: Label, variation: StringName, color: Variant = null) -> Label:
	label.theme_type_variation = variation
	if color != null:
		label.add_theme_color_override("font_color", color)
	return label

## Offset that centres a DESIGN-sized layout in the current viewport (stretch aspect
## "expand" gives wider/taller viewports on 20:9 phones and 4:3 tablets).
static func center_offset(node: CanvasItem, design: Vector2 = DESIGN) -> Vector2:
	var vp := node.get_viewport_rect().size
	return ((vp - design) * 0.5).max(Vector2.ZERO).floor()

## Keep `target` centred now and whenever the window is resized.
static func keep_centered(target: CanvasItem, design: Vector2 = DESIGN, extra: Vector2 = Vector2.ZERO) -> void:
	var apply := func():
		if is_instance_valid(target) and target.is_inside_tree():
			target.position = center_offset(target, design) + extra
	apply.call()
	if target.is_inside_tree():
		var vp := target.get_viewport()
		vp.size_changed.connect(apply)
		target.tree_exiting.connect(func():
			if vp.size_changed.is_connected(apply):
				vp.size_changed.disconnect(apply), CONNECT_ONE_SHOT)

## The 960-space type scale (plan 3.4) for code that sets sizes directly: snaps any
## requested size to 24 / 18 / 14 / 12 and adds the Large text delta.
static func fs(n: int) -> int:
	var snapped := 12
	if n >= 22:
		snapped = 24
	elif n >= 17:
		snapped = 18
	elif n >= 13:
		snapped = 14
	return snapped + GameState.ui_font_delta()
