extends RefCounted
## Language-aware content. English data files stay the source of truth (ids, numbers,
## pedagogy); for another language a sparse overlay with the same structure lives at
## res://data/i18n/<lang>/<path under data/> and is merged over it: objects key by key,
## arrays element by element (null keeps the English element), strings replace.

static func lang() -> String:
	return str(GameState.get_setting("language", "en"))

## Merge the current language's overlay (if any) into `data` loaded from `path`.
static func localize(path: String, data: Variant) -> Variant:
	if lang() == "en" or typeof(data) != TYPE_DICTIONARY or not path.begins_with("res://data/"):
		return data
	var over_path := "res://data/i18n/%s/%s" % [lang(), path.trim_prefix("res://data/")]
	if not FileAccess.file_exists(over_path):
		return data
	var over = JSON.parse_string(FileAccess.get_file_as_string(over_path))
	if typeof(over) != TYPE_DICTIONARY:
		return data
	return merge((data as Dictionary).duplicate(true), over)

## Deep merge `over` into `base` (base is modified and returned).
static func merge(base: Variant, over: Variant) -> Variant:
	if over == null:
		return base
	if typeof(base) == TYPE_DICTIONARY and typeof(over) == TYPE_DICTIONARY:
		for k in over.keys():
			base[k] = merge(base.get(k), over[k]) if base.has(k) else over[k]
		return base
	if typeof(base) == TYPE_ARRAY and typeof(over) == TYPE_ARRAY:
		for i in range(mini(base.size(), over.size())):
			base[i] = merge(base[i], over[i])
		return base
	return over

## Load a data JSON file with the current language's overlay applied.
static func json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return localize(path, JSON.parse_string(FileAccess.get_file_as_string(path)))
