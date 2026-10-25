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
