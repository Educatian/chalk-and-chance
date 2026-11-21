extends RefCounted
## Asset loader with graceful fallback. Used via `const Art = preload(...)` in consumers
## (preload avoids relying on the global class-name cache, which is only built by an
## editor scan and is missing on a fresh headless launch). Returns a Texture2D if the file exists and is
## imported, else null so callers can fall back to placeholder ColorRects. This lets
## imagegen2 PNGs drop into assets/ and light up the game with no code change.
## See ASSET_PROMPTS.md for the expected files and the Pokemon-style art spec.

static func tex(path: String) -> Texture2D:
	# The palette-matched v2 portrait wins over the pre-overhaul one wherever both exist,
	# so no screen can show the old painterly face by asking for the old path.
	if path.contains("/assets/portraits/"):
		var v2 := path.replace("/assets/portraits/", "/assets/v2/portraits/")
		if ResourceLoader.exists(v2):
			path = v2
	if ResourceLoader.exists(path):
		var res = load(path)   # Variant; do not use :=
		if res is Texture2D:
			return res
	return null

## A mission's picture (hub card, briefing, preview, cinematic, encounter backdrop): the
## pixel render of its own room, seats and roster from tools/art/thumbs.py, in the current
## classroom look (<id>_kr.png for the Korean room). Imported lessons use the topic-matched
## mission in "art_from", else their format's base mission. `thumb` is kept for callers; one 16:9 render serves both sizes.
const FORMAT_BASE := {"lecture": "lecture_fractions", "group_work": "group_work_fractions",
	"independent": "independent_fractions", "discussion": "discussion_fractions"}

static func scenario_backdrop_path(cfg: Dictionary, scenario_id: String = "", _thumb: bool = false, folder: String = "thumbs") -> String:
	var suffix := "_kr" if bool(GameState.get_setting("korean_classroom", false)) else ""
	var base := str(FORMAT_BASE.get(str(cfg.get("format", "discussion")), "discussion_fractions"))
	for id in [str(cfg.get("id", scenario_id)), str(cfg.get("art_from", "")), base]:
		for suf in [suffix, ""]:
			var p := "res://assets/v2/%s/%s%s.png" % [folder, id, suf]
			if id != "" and ResourceLoader.exists(p):
				return p
	return "res://assets/v2/%s/discussion_fractions.png" % folder

## Bounding box (region-local) of the non-transparent pixels inside `region` of a texture.
## Used to normalize character size by the DRAWN figure, not the cell (figures fill cells
## unevenly, which made on-screen heights inconsistent).
static func opaque_bounds(t: Texture2D, region: Rect2i) -> Rect2i:
	if t == null:
		return region
	var img := t.get_image()
	if img == null:
		return Rect2i(0, 0, region.size.x, region.size.y)
	if img.is_compressed():
		img.decompress()
	var minx := region.size.x
	var miny := region.size.y
	var maxx := -1
	var maxy := -1
	for y in range(region.size.y):
		for x in range(region.size.x):
			if img.get_pixel(region.position.x + x, region.position.y + y).a > 0.12:
				minx = min(minx, x)
				maxx = max(maxx, x)
				miny = min(miny, y)
				maxy = max(maxy, y)
	if maxx < 0:
		return Rect2i(0, 0, region.size.x, region.size.y)
	return Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)

## The furniture tiles (e.g. desk.png) are painted onto a copy of the floor tile. This
## removes every pixel that matches the floor so the object can sit in front of or behind
## characters, then crops to what is left. Cached per pair; null if either is missing.
static var _cutouts := {}

static func cutout(fg_path: String, floor_path: String) -> Texture2D:
	var key := fg_path + "|" + floor_path
	if _cutouts.has(key):
		return _cutouts[key]
	var fg := tex(fg_path)
	var bg := tex(floor_path)
	if fg == null or bg == null:
		return null
	var a := fg.get_image()
	var b := bg.get_image()
	if a == null or b == null or a.get_size() != b.get_size():
		return null
	if a.is_compressed():
		a.decompress()
	if b.is_compressed():
		b.decompress()
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			if absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) < 0.02:
				a.set_pixel(x, y, Color(0, 0, 0, 0))
	var used := a.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return null
	var out := ImageTexture.create_from_image(a.get_region(used))
	_cutouts[key] = out
	return out
