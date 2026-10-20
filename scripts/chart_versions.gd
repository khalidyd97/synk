class_name SynkChartVersions
extends RefCounted
# Version history for every chart level (original, easy, normal, hard, expert) of every song.
# Each save stores a numbered snapshot; switching writes a snapshot back as the live chart.
# Nothing is ever lost: before a switch, the live chart and any unsaved draft are recorded.

const LIMIT = 60

static func chart_file(song_id: String, level: String) -> String:
	return "user://charts/" + song_id + ("" if level == "original" else "_" + level) + ".json"
static func draft_file(song_id: String, level: String) -> String:
	return "user://drafts/" + song_id + "_" + level + ".json"
static func folder(song_id: String, level: String) -> String:
	return "user://chart_history/" + song_id + "_" + level

static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}

# Newest first. Each entry: {path, number, saved_at, notes, note, data}.
static func list(song_id: String, level: String) -> Array:
	var result: Array = []
	var dir = DirAccess.open(folder(song_id, level))
	if dir:
		for name in dir.get_files():
			if not name.ends_with(".json"): continue
			var data = read(folder(song_id, level).path_join(name))
			if data.is_empty() or str(data.get("song_id", "")) != song_id: continue
			var notes: Variant = SynkChart.notes_from_file(data)
			if notes == null: continue
			result.append({"path": folder(song_id, level).path_join(name), "number": int(data.get("history_number", 0)),
				"saved_at": str(data.get("saved_at", "")), "notes": notes.size(), "note": str(data.get("history_note", "")), "data": data})
	result.sort_custom(func(a, b): return int(a.number) > int(b.number))
	return result

static func next_number(song_id: String, level: String) -> int:
	var versions = list(song_id, level)
	return 1 if versions.is_empty() else int(versions[0].number) + 1

# Stores a snapshot unless it matches the newest one. Returns its version number (0 = skipped).
static func record(song_id: String, level: String, payload: Dictionary, note: String = "") -> int:
	var versions = list(song_id, level)
	if not versions.is_empty() and same(versions[0].data, payload): return 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder(song_id, level)))
	var number = 1 if versions.is_empty() else int(versions[0].number) + 1
	var data = payload.duplicate(true)
	data.history_number = number; data.history_note = note
	data.saved_at = Time.get_datetime_string_from_system()
	if SynkLibrary.atomic_write(folder(song_id, level).path_join("v%04d.json" % number), data) != OK: return 0
	# Keep the newest LIMIT versions.
	for old in versions.slice(LIMIT - 1):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(old.path))
	return number

# Compares notes and chart settings after a JSON round trip, so whole numbers read back from
# disk as floats still match the same values in memory.
static func same(a: Dictionary, b: Dictionary) -> bool:
	return canonical(a.get("notes", [])) == canonical(b.get("notes", [])) \
		and canonical(a.get("chart_settings", {})) == canonical(b.get("chart_settings", {}))
static func canonical(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)), "", true)

# Which version matches the live chart file, if any.
static func current_number(song_id: String, level: String) -> int:
	var live = read(chart_file(song_id, level))
	if live.is_empty(): return 0
	for entry in list(song_id, level):
		if same(entry.data, live): return int(entry.number)
	return 0

# Makes a stored version the live chart. The live chart and any unsaved draft are kept as
# versions first, so a switch can always be undone by switching back.
static func switch_to(song_id: String, level: String, path: String) -> Error:
	var target = read(path)
	if target.is_empty(): return ERR_FILE_NOT_FOUND
	var live = read(chart_file(song_id, level))
	if not live.is_empty(): record(song_id, level, strip(live), "Before switching")
	var draft = read(draft_file(song_id, level))
	if not draft.is_empty():
		record(song_id, level, strip(draft), "Unsaved draft kept before switching")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(draft_file(song_id, level)))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://charts"))
	return SynkLibrary.atomic_write(chart_file(song_id, level), strip(target))

static func strip(data: Dictionary) -> Dictionary:
	var clean = data.duplicate(true)
	for key in ["history_number", "history_note", "saved_at"]: clean.erase(key)
	return clean

static func remove_all(song_id: String) -> void:
	for level in preload("res://scripts/chart_levels.gd").every_variant():
		var dir = DirAccess.open(folder(song_id, level))
		if dir == null: continue
		for name in dir.get_files(): dir.remove(name)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder(song_id, level)))
