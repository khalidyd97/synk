class_name SynkCapture
extends RefCounted

var gestures: Dictionary = {}
var notes: Array = []

static func lane(x: float) -> float:
	return clampf((x - .07) / .86 * SynkChart.LANES - .5, 0, SynkChart.MAX_LANE)

func begin(id: int, time: float, p: Vector2, tool = "auto") -> bool:
	if time < 0 or p.x < .07 or p.x > .93 or p.y < .6 or p.y > .92 or gestures.has(id): return false
	var note_lane = roundi(lane(p.x))
	# Fingers landing together should become a chord, even when touch events arrive on separate frames.
	for gesture in gestures.values():
		var neighbor: Dictionary = gesture.note
		if int(neighbor.lane)!=note_lane and absf(time-float(neighbor.time))<=.06:
			time=float(neighbor.time); break
	if not notes.is_empty():
		var previous: Dictionary = notes.back()
		if int(previous.lane)!=note_lane and absf(time-float(previous.time))<=.06:
			time=float(previous.time)
	var n = SynkChart.note(time, note_lane)
	n.path.append({"offset": 0.0, "lane": float(n.lane)})
	gestures[id] = {"note": n, "tool": tool, "start": p, "position": p, "max_delta": 0.0}
	return true

func move(id: int, time: float, p: Vector2) -> void:
	if not gestures.has(id): return
	var g: Dictionary = gestures[id]; var n: Dictionary = g.note
	g.position = p; g.max_delta = maxf(float(g.max_delta), absf(lane(p.x) - float(n.lane)))
	n.duration = maxf(0, time - float(n.time)); n.end_lane = roundi(lane(p.x))
	if n.duration > float(n.path[-1].offset) + .016: n.path.append({"offset": n.duration, "lane": lane(p.x)})
	n.kind = "slide" if g.max_delta >= .8 else "hold"

func end(id: int, time: float, p: Vector2, canceled = false) -> Dictionary:
	if not gestures.has(id): return {}
	move(id, time, p)
	var g: Dictionary = gestures[id]; gestures.erase(id)
	if canceled: return {}
	var n: Dictionary = g.note
	n.kind = g.tool
	if g.tool == "auto": n.kind = "tap" if n.duration < .22 else ("slide" if g.max_delta >= .8 else "hold")
	if n.kind=="flick":
		var displacement: Vector2=p-g.start
		if maxf(absf(displacement.x),absf(displacement.y))<.035: return {}
		n.direction=(1 if displacement.x>0 else 3) if absf(displacement.x)>absf(displacement.y) else (2 if displacement.y>0 else 0)
		if n.direction==2: return {}
	if n.kind in ["tap","flick"]: n.duration = 0.0; n.path = []; n.end_lane = n.lane
	else:
		if n.duration < .04: return {}
		if n.kind == "hold": n.end_lane = n.lane; n.path = []
		else:
			if n.path[-1].offset == n.duration: n.path.pop_back()
			n.path.append({"offset": n.duration, "lane": float(n.end_lane)})
			n.path = snap_path(n.path, float(n.duration))
			n.end_lane = int(n.path[-1].lane)
	notes.append(n); return n

# How long (seconds) the finger must stay over a lane for the slide to lock onto it.
const DWELL = .12
# Smooth sections keep a point at most this often (seconds).
const SMOOTH_SPACING = .03

# Turns a hand-drawn slide path into a cleaner one. Lanes the finger rested on become flat
# runs locked to that lane; lanes it only swept across stay a smooth curve between them.
# The start and end always sit exactly on a lane.
static func snap_path(path: Array, duration: float) -> Array:
	if path.is_empty(): return path
	# Group consecutive points by the lane they are nearest to.
	var runs: Array = []
	for i in path.size():
		var lane_index = clampi(roundi(float(path[i].lane)), 0, SynkChart.MAX_LANE)
		if runs.is_empty() or runs[-1].lane != lane_index: runs.append({"lane": lane_index, "first": i, "last": i})
		else: runs[-1].last = i
	var result: Array = []
	var add_point = func(offset: float, lane_value: float, spaced: bool) -> void:
		if not result.is_empty():
			var gap = offset - float(result[-1].offset)
			if gap <= .0001 or (spaced and gap < SMOOTH_SPACING): return
		result.append({"offset": offset, "lane": clampf(lane_value, 0, SynkChart.MAX_LANE)})
	for r in runs.size():
		var run: Dictionary = runs[r]
		var start = float(path[run.first].offset); var finish = float(path[run.last].offset)
		# Time over this lane: from entering it until entering the next one.
		var left_at = float(path[runs[r+1].first].offset) if r < runs.size()-1 else duration
		if r == 0 or r == runs.size()-1 or left_at - start >= DWELL:
			add_point.call(start, float(run.lane), false)
			add_point.call(finish, float(run.lane), false)
		else:
			for i in range(run.first, run.last+1):
				# A light average with close neighbouring samples irons out finger jitter.
				var total = float(path[i].lane); var weight = 1.0
				for j in [i-1, i+1]:
					if j >= 0 and j < path.size() and absf(float(path[j].offset) - float(path[i].offset)) <= .05:
						total += float(path[j].lane); weight += 1.0
				add_point.call(float(path[i].offset), total / weight, true)
	if float(result[-1].offset) < duration: result.append({"offset": duration, "lane": result[-1].lane})
	return result

# Evenly spaced samples of a slide's current shape, used before reshaping it.
static func sample_path(n: Dictionary, spacing: float = .02) -> Array:
	var duration = float(n.duration)
	var count = maxi(2, ceili(duration / spacing))
	var result: Array = []
	for i in count + 1:
		var offset = duration * i / count
		result.append({"offset": offset, "lane": SynkChart.lane_at(n, float(n.time) + offset)})
	return result

# A softly curved version of the slide's shape; the start and end lanes stay put.
static func smooth_path(n: Dictionary) -> Array:
	var points = sample_path(n, .05)
	for pass_index in 3:
		var next = points.duplicate(true)
		for i in range(1, points.size()-1):
			next[i].lane = (float(points[i-1].lane) + float(points[i].lane)*2.0 + float(points[i+1].lane)) / 4.0
		points = next
	return points
