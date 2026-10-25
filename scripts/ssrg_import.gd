extends RefCounted
# Reads SSRG chart files (.bytes) that the player brings in from their own copy of the game.
# Nothing from SSRG ships with SYNK; this only understands the file layout.
#   header: song length (double, 0x08), ticks per beat (uint, 0x10), note count (uint, 0x2c),
#           BPM (double, 0x50); the header fills the file up to the note records.
#   records: 24 bytes each - tick (int64), position 0..12, flag, type, unused.
#   types: 0 tap; 21 then 22s = one finger's long note, 11 then 12s = the other finger's.
#          Positions above 12 are start/end markers.
# A long note that stays in place is a hold and one that moves is a slide, however short:
# SSRG has no flicks. The 13 positions spread across SYNK's 10 lanes. The song audio is plain Ogg Vorbis.
const RECORD = 24

static func is_audio(bytes: PackedByteArray) -> bool:
	return bytes.size() >= 4 and bytes.slice(0, 4).get_string_from_ascii() == "OggS"

static func lane(position: int) -> float:
	return clampf(position * float(SynkChart.MAX_LANE) / 12.0, 0, SynkChart.MAX_LANE)

# Returns {keys, bpm, length, title, notes} or {} when the file is not an SSRG chart.
static func parse(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 0x58 + RECORD: return {}
	var count = bytes.decode_u32(0x2c)
	var header = bytes.size() - count * RECORD
	if count == 0 or count > 100000 or header < 0x58: return {}
	var bpm = bytes.decode_double(0x50)
	var song_length = bytes.decode_double(0x08)
	var ticks = bytes.decode_u32(0x10)
	if ticks == 0: ticks = 256
	if not is_finite(bpm) or bpm < 20 or bpm > 500: return {}
	var seconds_per_tick = 60.0 / bpm / ticks
	var positions = {}
	var taps: Array = []
	var chains = {21: [], 11: []}
	var open = {21: null, 11: null}
	for i in count:
		var at = header + i * RECORD
		var tick = bytes.decode_s64(at)
		var position = bytes.decode_u32(at + 8)
		var kind = bytes.decode_u32(at + 16)
		if position > 12 or tick < 0: continue
		positions[position] = true
		var point = {"time": tick * seconds_per_tick, "position": position}
		match kind:
			0: taps.append(point)
			21, 11:
				open[kind] = [point]; chains[kind].append(open[kind])
			22, 12:
				var start = 21 if kind == 22 else 11
				if open[start] == null: taps.append(point)
				else: open[start].append(point)
			_: return {}
	if positions.is_empty(): return {}
	var keys = 13
	if positions.keys().all(func(p): return p % 4 == 0): keys = 4
	elif positions.keys().all(func(p): return p % 2 == 0): keys = 7
	var notes: Array = []
	var taken = {}
	for point in taps:
		var n = SynkChart.note(point.time, roundi(lane(point.position)))
		n.lane=lane(point.position); n.end_lane=n.lane
		var key = "%d|%d" % [roundi(n.time * 1000), point.position]
		if taken.has(key): continue
		taken[key] = true; notes.append(n)
	for start in chains:
		for chain in chains[start]: notes.append(long_note(chain))
	notes.sort_custom(func(a, b): return a.time < b.time)
	return {"keys": keys, "bpm": bpm, "length": song_length, "title": title_from(bytes, header), "notes": notes}

static func long_note(chain: Array) -> Dictionary:
	var first: Dictionary = chain[0]; var last: Dictionary = chain[-1]
	var n = SynkChart.note(first.time, roundi(lane(first.position)))
	n.lane=lane(first.position); n.end_lane=n.lane
	var duration = float(last.time) - float(first.time)
	if chain.size() < 2 or duration <= 0: return n
	# Continuation records are playable connector pucks, not just curve samples.
	n.checkpoints = []
	for p in chain:
		var offset = float(p.time) - float(first.time)
		if offset > 0 and offset < duration and (n.checkpoints.is_empty() or offset > float(n.checkpoints[-1])):
			n.checkpoints.append(offset)
	var moves = chain.any(func(p): return p.position != first.position)
	if not moves:
		n.kind = "hold"; n.duration = duration
	else:
		n.kind = "slide"; n.duration = duration; n.end_lane = lane(last.position)
		var previous = -1.0
		for p in chain:
			var offset = float(p.time) - float(first.time)
			if offset <= previous: continue
			n.path.append({"offset": offset, "lane": lane(p.position)}); previous = offset
	return n

# "sc_teddy_bear.ogg" in the header becomes "Teddy Bear".
static func title_from(bytes: PackedByteArray, header: int) -> String:
	var printable = bytes.slice(0, header)
	for i in printable.size():
		if printable[i] < 32 or printable[i] > 126: printable[i] = 32
	var text = printable.get_string_from_ascii()
	var found = RegEx.create_from_string(r"([A-Za-z0-9_\-]+)\.ogg").search(text)
	if found == null: return ""
	var name = found.get_string(1)
	if name.begins_with("sc_"): name = name.substr(3)
	return name.replace("_", " ").capitalize()

# The audio name a chart's header points at, without ".ogg" ("FTISLAND_Severely"), or "".
static func audio_name(bytes: PackedByteArray) -> String:
	var count = bytes.decode_u32(0x2c) if bytes.size() >= 0x30 else 0
	var header = bytes.size() - count * RECORD
	if header < 0x58 or header > bytes.size(): header = mini(bytes.size(), 4096)
	var printable = bytes.slice(0, header)
	for i in printable.size():
		if printable[i] < 32 or printable[i] > 126: printable[i] = 32
	var found = RegEx.create_from_string(r"([A-Za-z0-9_\-.()' ]+?)\.ogg").search(printable.get_string_from_ascii())
	return found.get_string(1).strip_edges() if found else ""

# "FTISLAND_Severely" -> ["FTISLAND", "Severely"]: artist before the first underscore.
static func artist_and_title(name: String) -> Array:
	var cut = name.find("_")
	if cut <= 0: return ["", name.replace("_", " ").strip_edges()]
	return [name.substr(0, cut).replace("_", " ").strip_edges(), name.substr(cut + 1).replace("_", " ").strip_edges()]

# --- Phone library: <root>/<GAME>/{seq, music, background} ----------------------------
# Charts are <song id>_<keys>.seq (or .bytes); the music file is the one the chart's header
# names (or one named after the song id); the background is an image named after the song id
# or the music. Returns one entry per song:
#   {game, song_id, charts {keys: path}, audio, background, name}
const CHART_EXTENSIONS = ["seq", "bytes"]
const IMAGE_EXTENSIONS = ["png", "jpg", "jpeg", "webp"]

static func subfolder(base: String, wanted: String) -> String:
	for name in DirAccess.get_directories_at(base):
		if name.to_lower() == wanted: return base.path_join(name)
	return ""

static func files_in(folder: String) -> PackedStringArray:
	return DirAccess.get_files_at(folder) if not folder.is_empty() else PackedStringArray()

# The file in `names` whose name (without extension) matches one of `stems`, ignoring case.
static func match_file(folder: String, names: PackedStringArray, stems: Array, extensions: Array = []) -> String:
	for stem in stems:
		if str(stem).is_empty(): continue
		for name in names:
			if not extensions.is_empty() and name.get_extension().to_lower() not in extensions: continue
			if name.get_basename().to_lower() == str(stem).to_lower(): return folder.path_join(name)
	return ""

static func scan(root: String) -> Array:
	var songs: Array = []
	if not DirAccess.dir_exists_absolute(root): return songs
	var games = Array(DirAccess.get_directories_at(root)); games.sort()
	for game_name in games:
		var base = root.path_join(game_name)
		var seq_dir = subfolder(base, "seq"); var music_dir = subfolder(base, "music"); var art_dir = subfolder(base, "background")
		var music = files_in(music_dir); var art = files_in(art_dir)
		var grouped = {}
		for name in files_in(seq_dir):
			if name.get_extension().to_lower() not in CHART_EXTENSIONS: continue
			var stem = name.get_basename(); var cut = stem.rfind("_")
			var song_id = stem.substr(0, cut) if cut > 0 else stem
			var keys = int(stem.substr(cut + 1)) if cut > 0 and stem.substr(cut + 1).is_valid_int() else 0
			if not grouped.has(song_id): grouped[song_id] = {}
			grouped[song_id][keys if keys in [4, 7, 13] else grouped[song_id].size() + 100] = seq_dir.path_join(name)
		var ids = grouped.keys(); ids.sort()
		for song_id in ids:
			var charts: Dictionary = grouped[song_id]
			var name = audio_name(FileAccess.get_file_as_bytes(charts.values()[0]))
			songs.append({"game": game_name, "song_id": song_id, "charts": charts, "name": name,
				"audio": match_file(music_dir, music, [name, song_id]),
				"background": match_file(art_dir, art, [song_id, name], IMAGE_EXTENSIONS)})
	return songs

# Changes when any of the song's files change, so an unchanged song is not imported again.
static func signature(entry: Dictionary) -> String:
	var parts: Array = []
	for path in entry.charts.values() + [entry.audio, entry.background]:
		if not str(path).is_empty(): parts.append("%s:%d" % [str(path).get_file(), FileAccess.get_modified_time(path)])
	return "|".join(parts)
