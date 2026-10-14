class_name SynkCapture
extends RefCounted

var gestures: Dictionary = {}
var notes: Array = []

static func lane(x: float) -> float:
	return clampf((x - .07) / .86 * 13 - .5, 0, 12)

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
	notes.append(n); return n
