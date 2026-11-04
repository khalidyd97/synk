extends RefCounted
# Reads SSRG chart files (.bytes) that the player brings in from their own copy of the game.
# Nothing from SSRG ships with SYNK; this only understands the file layout.
#   header: song length (double, 0x08), ticks per beat (uint, 0x10), note count (uint, 0x2c),
#           BPM (double, 0x50); the header fills the file up to the note records.
#   records: 24 bytes each - tick (int64), position 0..12, flag, type, unused.
#   types: 0 tap; 21 then 22s = one finger's long note, 11 then 12s = the other finger's.
#          Positions above 12 are markers. The one flagged 1 is where the music starts: chart
#          ticks count from before the audio (1004_13.seq: tick 896, and onsets in its .ogg
#          line up with the notes only when 1.721 s is taken off). Position 13 is the end.
# A long note that stays in place is a hold and one that moves is a slide, however short:
# SSRG has no flicks. The 13 positions map directly to SYNK's 13 lanes. The song audio is plain Ogg Vorbis.
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
	if not is_finite(song_length) or song_length<=0:return {}
	var seconds_per_tick = 60.0 / bpm / ticks
	var start_tick = 0
	for i in count:
		var at = header + i * RECORD
		if bytes.decode_u32(at + 8) > 12 and bytes.decode_u32(at + 12) == 1:
			start_tick = maxi(0, bytes.decode_s64(at)); break
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
		var point = {"time": (tick - start_tick) * seconds_per_tick, "position": position, "order":i,"tick":tick}
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
	for point in taps:
		var n = SynkChart.note(point.time, roundi(lane(point.position)))
		n.lane=lane(point.position); n.end_lane=n.lane
		n.ssrg_order=int(point.order)
		n.ssrg_tick=int(point.tick);n.ssrg_raw_time=float(point.time)
		notes.append(n)
	for start in chains:
		for chain in chains[start]: notes.append(long_note(chain))
	notes.sort_custom(func(a, b): return a.time < b.time if not is_equal_approx(float(a.time),float(b.time)) else int(a.ssrg_order)<int(b.ssrg_order))
	# Beats stay on chart ticks that are multiples of a beat, now counted from the music start.
	var beat_offset = posmod(-start_tick, ticks) * seconds_per_tick
	return {"keys": keys, "bpm": bpm, "length": song_length - start_tick * seconds_per_tick, "beat_offset": beat_offset,
		"title": title_from(bytes, header), "notes": notes,
		"source":{"ticks_per_beat":ticks,"start_tick":start_tick,"record_count":count,"header_size":header,"header_base64":Marshalls.raw_to_base64(bytes.slice(0,header)),"parser_version":4}}

static func long_note(chain: Array) -> Dictionary:
	var first: Dictionary = chain[0]; var last: Dictionary = chain[-1]
	var n = SynkChart.note(first.time, roundi(lane(first.position)))
	n.lane=lane(first.position); n.end_lane=n.lane
	n.ssrg_order=int(first.order)
	n.ssrg_tick=int(first.get("tick",0));n.ssrg_raw_time=float(first.time)
	n.ssrg_orders=[]
	for point in chain: n.ssrg_orders.append({"offset":float(point.time)-float(first.time),"order":int(point.order),"tick":int(point.get("tick",0))})
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
	if name.begins_with("sc_"):return ["",name.substr(3).replace("_"," ").capitalize()]
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
const AUDIO_EXTENSIONS = ["ogg", "mp3", "wav", "bytes"]

static func subfolder(base: String, wanted: Variant) -> String:
	var names: Array = wanted if wanted is Array else [wanted]
	for name in DirAccess.get_directories_at(base):
		if name.to_lower() in names: return base.path_join(name)
	return ""

# Files in a folder and its subfolders (one level), as paths.
static func files_deep(folder: String) -> PackedStringArray:
	var result = PackedStringArray()
	if folder.is_empty(): return result
	for name in DirAccess.get_files_at(folder): result.append(folder.path_join(name))
	for sub in DirAccess.get_directories_at(folder):
		for name in DirAccess.get_files_at(folder.path_join(sub)): result.append(folder.path_join(sub).path_join(name))
	return result

# Lower case letters and digits only: "FTISLAND - Severely (1).ogg" and "ftisland_severely" meet.
static func simple(text: String) -> String:
	var out = ""
	for ch in text.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"): out += ch
	return out

# Export wrappers are not part of a song ID or a level suffix.
static func file_stem(value:String)->String:
	var stem=value.replace("\\","/").get_file()
	while stem.get_extension().to_lower() in ["ogg","wav","mp3","bytes","seq","png","jpg","jpeg","webp"]:stem=stem.get_basename()
	return stem

static func leading_id(value:String)->String:
	var result=""
	for ch in file_stem(value):
		if ch>="0" and ch<="9":result+=ch
		else:break
	return result

static func level_hint(value:String)->int:
	var stem=file_stem(value);var cut=stem.rfind("_")
	if cut<0:return 0
	var tail=stem.substr(cut+1)
	return int(tail) if tail.is_valid_int() and int(tail) in [4,7,13] else 0

static func song_key(value:String)->String:
	var numeric=leading_id(value)
	if not numeric.is_empty():return numeric
	var stem=file_stem(value)
	return stem.substr(0,stem.rfind("_")) if level_hint(value)>0 else stem

static func match_score(path:String,stems:Array,primary_id:String="")->int:
	var expected=leading_id(primary_id);var actual=leading_id(path)
	if not expected.is_empty() and not actual.is_empty():return 2000 if expected==actual else 0
	var have=simple(file_stem(path));var score=0
	for i in stems.size():
		var wanted=simple(file_stem(str(stems[i])))
		if wanted.is_empty():continue
		if have==wanted:score=maxi(score,1000-i)
		elif wanted.length()>=4 and (have.contains(wanted) or wanted.contains(have)):score=maxi(score,500-i)
	return score

static func find_file(paths:PackedStringArray,stems:Array,extensions:Array=[],primary_id:String="")->String:
	var best="";var best_score=0;var tied=false
	for path in paths:
		if not extensions.is_empty() and path.get_extension().to_lower() not in extensions:continue
		var score=match_score(path,stems,primary_id)
		if score>best_score:best=path;best_score=score;tied=false
		elif score==best_score and score>0:tied=true
	return "" if tied else best

static func files_in(folder: String) -> PackedStringArray:
	return DirAccess.get_files_at(folder) if not folder.is_empty() else PackedStringArray()

static func scan(root: String) -> Array:
	var songs: Array = []
	if not DirAccess.dir_exists_absolute(root): return songs
	var games = Array(DirAccess.get_directories_at(root)); games.sort()
	for game_name in games:
		var base = root.path_join(game_name)
		var seq_dir = subfolder(base, ["seq", "seqs", "chart", "charts"])
		var music_dir = subfolder(base, ["music", "musics", "bgm", "audio", "sound", "sounds", "songs"])
		var art_dir = subfolder(base, ["background", "backgrounds", "bg", "image", "images"])
		var music = files_deep(music_dir); var art = files_deep(art_dir)
		var grouped = {}
		for name in files_in(seq_dir):
			if name.get_extension().to_lower() not in CHART_EXTENSIONS: continue
			var song_id=song_key(name)
			var keys=level_hint(name)
			if not grouped.has(song_id): grouped[song_id] = {}
			grouped[song_id][keys if keys in [4, 7, 13] else grouped[song_id].size() + 100] = seq_dir.path_join(name)
		var ids = grouped.keys(); ids.sort()
		for song_id in ids:
			var charts: Dictionary = grouped[song_id]
			var name = audio_name(FileAccess.get_file_as_bytes(charts.values()[0]))
			songs.append({"game": game_name, "song_id": song_id, "charts": charts, "name": name,
				"audio": find_file(music, [name, song_id], AUDIO_EXTENSIONS,song_id),
				"background": find_file(art, [song_id, name], IMAGE_EXTENSIONS,song_id),
				"music_dir": music_dir, "music_files": music.size()})
	return songs

# Changes when any of the song's files change, so an unchanged song is not imported again.
static func signature(entry: Dictionary) -> String:
	# Bumped when parsing changes, so songs imported before are read again (v2: music start).
	var parts: Array = ["v4"]
	for path in entry.charts.values() + [entry.audio, entry.background]:
		if not str(path).is_empty(): parts.append("%s:%s" % [str(path).get_file(), FileAccess.get_sha256(path)])
	if not entry.charts.is_empty():
		var sidecar=str(entry.charts.values()[0]).get_base_dir().path_join("presentation.json")
		if FileAccess.file_exists(sidecar):parts.append("presentation:"+FileAccess.get_sha256(sidecar))
	return "|".join(parts)

static func report(bytes:PackedByteArray,hinted_keys:int=0) -> Dictionary:
	var result={"chart":{},"errors":[],"warnings":[]}
	if bytes.size()<0x58+RECORD:
		result.errors.append("Chart header or records are truncated.");return result
	var count=int(bytes.decode_u32(0x2c));var header=bytes.size()-count*RECORD
	if count<=0 or count>100000 or header<0x58:
		result.errors.append("Invalid chart record count or layout.");return result
	var starts=0;var open_ticks={};var unsupported={};var early=0;var markers=0;var ambiguous=0
	var chain_counts={}
	var start_tick=0
	for i in count:
		var at=header+i*RECORD
		if bytes.decode_u32(at+8)>12 and bytes.decode_u32(at+12)==1:
			starts+=1;start_tick=bytes.decode_s64(at)
	for i in count:
		var at=header+i*RECORD;var tick=bytes.decode_s64(at);var position=int(bytes.decode_u32(at+8));var kind=int(bytes.decode_u32(at+16))
		if position>12:
			markers+=1
			if bytes.decode_u32(at+12) not in [0,1] or kind not in [0,11,12,21,22]:ambiguous+=1
			continue
		if tick<start_tick:early+=1
		if kind not in [0,11,12,21,22]:unsupported[kind]=true
		if hinted_keys in [4,7,13] and position%(12/(hinted_keys-1))!=0:
			result.errors.append("Lane positions do not match the named %d-key difficulty." % hinted_keys);break
		if kind in [11,21]:
			if int(chain_counts.get(kind,0))==1:result.warnings.append("Long-note head without a continuation is represented as a tap; original retained.")
			open_ticks[kind]=tick;chain_counts[kind]=1
		elif kind in [12,22]:
			var channel=11 if kind==12 else 21
			if not open_ticks.has(channel):result.warnings.append("Orphan connector at record %d is represented as a tap; original retained." % i)
			elif tick<=int(open_ticks[channel]):result.errors.append("Non-increasing or simultaneous connector ticks at record %d are unsupported." % i)
			open_ticks[channel]=tick
			chain_counts[channel]=int(chain_counts.get(channel,0))+1
	for amount in chain_counts.values():
		if int(amount)==1:result.warnings.append("Long-note head without a continuation is represented as a tap; original retained.")
	if bytes.decode_u32(0x10)==0:result.warnings.append("Ticks per beat were unspecified; the legacy 256-tick default is used.")
	if starts>1:result.errors.append("Multiple music-start markers; timing is ambiguous.")
	if not unsupported.is_empty():result.errors.append("Unsupported playable record types: %s (%d types)" % [str(unsupported.keys().slice(0,8)),unsupported.size()])
	if early>0:result.errors.append("%d notes precede the music-start marker; importing would clamp their timing." % early)
	if ambiguous>0:result.errors.append("%d unrecognized marker records; constant-tempo timing cannot be verified." % ambiguous)
	if result.errors.size()>16:result.errors.resize(16);result.errors.append("Additional invalid records exist; original file was not changed.")
	if result.warnings.size()>16:result.warnings.resize(16);result.warnings.append("Additional recoverable record warnings exist; original file is retained.")
	if not result.errors.is_empty():return result
	var chart=parse(bytes)
	if chart.is_empty():result.errors.append("Invalid BPM, lane data, or unsupported chart structure.");return result
	if not is_finite(float(chart.length)) or float(chart.length)<=0:result.errors.append("Invalid declared song length.")
	if not SynkChart.valid(chart.notes):result.errors.append("Chart contains invalid note timing or connector geometry.")
	if hinted_keys in [4,7,13]:chart.keys=hinted_keys
	chart.source.marker_count=markers
	result.chart=chart
	return result
