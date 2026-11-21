extends RefCounted
## Asset loader with graceful fallback. Used via `const Art = preload(...)` in consumers
## (preload avoids relying on the global class-name cache, which is only built by an
## editor scan and is missing on a fresh headless launch). Returns a Texture2D if the file exists and is
## imported, else null so callers can fall back to placeholder ColorRects. This lets
## imagegen2 PNGs drop into assets/ and light up the game with no code change.
## See ASSET_PROMPTS.md for the expected files and the Pokemon-style art spec.

static func tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res = load(path)   # Variant; do not use :=
		if res is Texture2D:
			return res
	return null

static func scenario_backdrop_path(cfg: Dictionary, scenario_id: String = "", thumb: bool = false) -> String:
	var key := "backdrop_thumb" if thumb else "backdrop"
	var p := str(cfg.get(key, ""))
	if p != "":
		return p
	var id := str(cfg.get("id", scenario_id))
	if id != "":
		var candidate := "res://assets/backdrops/%s%s.png" % [id, "_thumb" if thumb else ""]
		if ResourceLoader.exists(candidate):
			return candidate
	var fmt := str(cfg.get("format", "discussion"))
	match fmt:
		"lecture": return "res://assets/backdrops/lecture_fractions%s.png" % ("_thumb" if thumb else "")
		"group_work": return "res://assets/backdrops/group_work_fractions%s.png" % ("_thumb" if thumb else "")
		"independent": return "res://assets/backdrops/independent_fractions%s.png" % ("_thumb" if thumb else "")
		_: return "res://assets/backdrops/discussion_fractions%s.png" % ("_thumb" if thumb else "")

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
