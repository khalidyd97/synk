class_name SynkChart
extends RefCounted

const TYPES = ["tap", "hold", "slide", "flick"]
var notes: Array = []
var selected = -1
var dirty = false
var undo_stack: Array = []
var redo_stack: Array = []

static func note(time: float, lane: int, kind = "tap") -> Dictionary:
	return {"time": maxf(0, time), "lane": clampi(lane, 0, 12), "kind": kind, "duration": 0.0, "end_lane": clampi(lane, 0, 12), "direction": 0, "path": []}

static func lane_at(n: Dictionary, time: float) -> float:
	if n.kind != "slide": return float(n.lane)
	var elapsed = clampf(time - float(n.time), 0, float(n.duration))
	var path: Array = n.get("path", [])
	for i in range(1, path.size()):
		if elapsed <= float(path[i].offset):
			var t = (elapsed - float(path[i-1].offset)) / maxf(.0001, float(path[i].offset) - float(path[i-1].offset))
			return lerpf(float(path[i-1].lane), float(path[i].lane), t)
	if path.size() > 1: return float(path[-1].lane)
	return lerpf(float(n.lane), float(n.end_lane), smoothstep(0, maxf(.01, float(n.duration)), elapsed))

func load_notes(source: Array) -> void:
	notes = source.duplicate(true)
	for n in notes:
		if n.kind=="flick" and int(n.direction)==2: n.direction=0
	selected = -1; dirty = false; undo_stack.clear(); redo_stack.clear()

func checkpoint() -> void:
	undo_stack.append(notes.duplicate(true))
	if undo_stack.size() > 100: undo_stack.pop_front()
	redo_stack.clear(); dirty = true

func undo() -> void:
	if undo_stack.is_empty(): return
	redo_stack.append(notes.duplicate(true)); notes = undo_stack.pop_back(); selected = -1; dirty = true

func redo() -> void:
	if redo_stack.is_empty(): return
	undo_stack.append(notes.duplicate(true)); notes = redo_stack.pop_back(); selected = -1; dirty = true

func selection() -> Dictionary:
	return notes[selected] if selected >= 0 and selected < notes.size() else {}

func add(time: float, lane: int) -> void:
	checkpoint(); notes.append(note(time, lane)); selected = notes.size() - 1

func delete() -> void:
	if selection().is_empty(): return
	checkpoint(); notes.remove_at(selected); selected = -1

func convert(kind: String, beat: float, song_end: float) -> void:
	var n = selection()
	if n.is_empty(): return
	checkpoint(); n.kind = kind
	if kind=="flick" and int(n.direction)==2: n.direction=0
	if kind in ["tap", "flick"]: n.duration = 0.0; n.path = []; n.end_lane = n.lane
	else:
		n.duration = maxf(.04, float(n.duration) if float(n.duration) > 0 else beat)
		if kind == "hold": n.path = []; n.end_lane = n.lane
	move_note(float(n.time), int(n.lane), song_end)

func move_note(time: float, lane: int, song_end: float) -> void:
	var n = selection()
	if n.is_empty(): return
	n.time = clampf(time, 0, maxf(0, song_end - float(n.duration)))
	var delta = clampi(lane, 0, 12) - int(n.lane)
	n.lane += delta; n.end_lane = clampi(int(n.end_lane) + delta, 0, 12)
	for p in n.path: p.lane = clampf(float(p.lane) + delta, 0, 12)
	dirty = true

func resize(duration: float, song_end: float) -> void:
	var n = selection()
	if n.is_empty() or n.kind in ["tap", "flick"]: return
	checkpoint(); var previous = maxf(.04, float(n.duration))
	n.duration = clampf(duration, .04, maxf(.04, song_end - float(n.time)))
	for p in n.path: p.offset = float(p.offset) * float(n.duration) / previous

static func snap(time: float, bpm: float, division: int) -> float:
	return maxf(0, time) if division == 0 else maxf(0, snappedf(time, 60.0 / bpm / division))

static func valid(source: Variant) -> bool:
	if not source is Array or source.size() > 100000: return false
	for n in source:
		if not n is Dictionary: return false
		for key in ["time", "lane", "kind", "duration", "end_lane", "direction", "path"]:
			if not n.has(key): return false
		for key in ["time", "lane", "duration", "end_lane", "direction"]:
			if not (n[key] is float or n[key] is int) or not is_finite(float(n[key])): return false
		if n.kind not in TYPES or n.time < 0 or n.duration < 0 or n.lane < 0 or n.lane > 12 or n.end_lane < 0 or n.end_lane > 12 or n.direction < 0 or n.direction > 3: return false
		if not n.path is Array: return false
		var previous = -1.0
		for p in n.path:
			if not p is Dictionary or not p.has("offset") or not p.has("lane"): return false
			if not (p.offset is float or p.offset is int) or not (p.lane is float or p.lane is int): return false
			if not is_finite(float(p.offset)) or not is_finite(float(p.lane)) or p.offset <= previous or p.offset < 0 or p.offset > n.duration or p.lane < 0 or p.lane > 12: return false
			previous = p.offset
	return true

static func demo() -> Array:
	var result: Array = []
	var random = RandomNumberGenerator.new(); random.seed = 42
	for i in 96:
		var n = note(3 + i * 60.0 / 128 * 2, random.randi_range(1, 11), "tap" if i < 8 else TYPES[i % 4])
		n.duration = 60.0 / 128 if n.kind in ["hold", "slide"] else 0.0
		n.end_lane = clampi(int(n.lane) + (3 if i % 2 == 0 else -3), 0, 12); n.direction = [0,1,3][(i / 4) % 3]
		result.append(n)
	return result
