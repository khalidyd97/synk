extends RefCounted
# Chart levels: every chart of a song is tagged with an intensity from Lv 1 to Lv 30.
# A level's key is "lv<N>" and its file is user://charts/<song>_lv<N>.json, so one song can
# have several charts (Lv 5, Lv 18, ...). Charts saved before levels used the names
# original/easy/normal/hard/expert; those files are kept on disk but no longer listed.
const MAX_LEVEL = 30
const LEGACY = ["original", "easy", "normal", "hard", "expert"]

static func key(level: int) -> String: return "lv%d" % clampi(level, 1, MAX_LEVEL)
static func number(variant: String) -> int:
	return int(variant.substr(2)) if is_level(variant) else 0
static func is_level(variant: String) -> bool:
	return variant.begins_with("lv") and variant.substr(2).is_valid_int() and int(variant.substr(2)) >= 1 and int(variant.substr(2)) <= MAX_LEVEL
static func label(variant: String) -> String:
	return "Lv %d" % number(variant) if is_level(variant) else variant.capitalize()
static func all_keys() -> Array:
	var keys: Array = []
	for n in range(1, MAX_LEVEL + 1): keys.append(key(n))
	return keys
# Every variant name a song may have files under, old and new (used when deleting a song).
static func every_variant() -> Array: return LEGACY + all_keys()
static func chart_path(song_id: String, variant: String) -> String:
	return "user://charts/" + song_id + "_" + variant + ".json"
# The levels this song has a saved chart for, lowest first.
static func existing(song_id: String) -> Array:
	var found: Array = []
	var dir = DirAccess.open("user://charts")
	if dir == null: return found
	var prefix = song_id + "_lv"
	for name in dir.get_files():
		if not name.begins_with(prefix) or not name.ends_with(".json"): continue
		var variant = name.trim_prefix(song_id + "_").trim_suffix(".json")
		if is_level(variant): found.append(variant)
	found.sort_custom(func(a, b): return number(a) < number(b))
	return found
