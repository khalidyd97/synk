class_name SynkCapture
extends RefCounted

var gestures: Dictionary = {}
var notes: Array = []
var minimum_lane_gap=2.4
var chord_starts: Array=[]
var last_spacing_resolved=true
var onset_bounds=Vector2(0,INF)
const CHORD_WINDOW=.06

static func lane(x: float) -> float:
	return clampf((x - .07) / .86 * SynkChart.LANES - .5, 0, SynkChart.MAX_LANE)

func begin(id: int, time: float, p: Vector2, tool = "auto",fixed: Array=[], allowed_types: Array=[]) -> bool:
	if time < 0 or p.x < .07 or p.x > .93 or p.y < .6 or p.y > .92 or gestures.has(id): return false
	var note_lane = roundi(lane(p.x))
	var raw_time=time
	# Use the original onset, not release order. Never chain an entire fast roll into one chord.
	chord_starts=chord_starts.filter(func(entry): return absf(raw_time-float(entry.input_time))<=CHORD_WINDOW and current_note(entry.note))
	for entry in chord_starts:
		if (entry.id!=id or entry.raw_lane!=note_lane) and absf(raw_time-float(entry.note.time))<=CHORD_WINDOW:
			time=float(entry.note.time); break
	if time==raw_time:
		var closest=CHORD_WINDOW+.00001
		for previous in fixed:
			if float(previous.time)<onset_bounds.x or float(previous.time)>=onset_bounds.y: continue
			var distance=absf(raw_time-float(previous.time))
			if distance<closest: time=float(previous.time); closest=distance
	var n = SynkChart.note(time, note_lane)
	n.path.append({"offset": 0.0, "lane": float(n.lane)})
	var allowed = allowed_types.duplicate() if not allowed_types.is_empty() else (["tap", "hold", "slide"] if tool == "auto" else [tool])
	gestures[id] = {"note": n, "tool": tool, "allowed": allowed, "start": p, "position": p, "max_delta": 0.0,"lane_shift":float(note_lane)-lane(p.x),"samples":n.path.duplicate(true),"raw_lane":note_lane,"fixed":fixed}
	chord_starts.append({"note":n,"id":id,"input_time":raw_time,"raw_lane":note_lane})
	space_chord(n,fixed)
	return true

func current_note(n: Dictionary) -> bool:
	for other in notes:
		if is_same(n,other): return true
	for gesture in gestures.values():
		if is_same(n,gesture.note): return true
	return false

func space_chord(n: Dictionary,fixed: Array) -> void:
	var movable=notes.duplicate(); var before: Dictionary={}
	for id in gestures:
		movable.append(gestures[id].note); before[id]=int(gestures[id].note.lane)
	last_spacing_resolved=SynkNoteSpacing.place(n,movable,fixed,minimum_lane_gap).resolved
	# A moved gesture keeps following its finger with a constant lane offset.
	for id in gestures:
		var delta=int(gestures[id].note.lane)-int(before[id])
		gestures[id].lane_shift+=delta
		if delta!=0:
			for point in gestures[id].samples:point.lane=clampf(float(point.lane)+delta,0,SynkChart.MAX_LANE)

func move(id: int, time: float, p: Vector2) -> void:
	if not gestures.has(id): return
	var g: Dictionary = gestures[id]; var n: Dictionary = g.note
	g.position = p; g.max_delta = maxf(float(g.max_delta), absf(lane(p.x)-lane(g.start.x)))
	var mapped_lane=clampf(lane(p.x)+float(g.get("lane_shift",0)),0,SynkChart.MAX_LANE)
	n.duration = maxf(float(n.duration),maxf(0,time-float(n.time)));n.end_lane=roundi(mapped_lane)
	var samples:Array=g.samples
	if n.duration>float(samples[-1].offset)+.0001:samples.append({"offset":n.duration,"lane":mapped_lane})
	elif samples.size()>1:samples[-1].lane=mapped_lane
	n.kind = str(g.tool) if g.tool in ["hold","slide"] else ("slide" if g.max_delta>=.8 else "hold")
	if n.kind=="slide" and n.duration>.04:
		n.path=snap_path(samples,n.duration);n.ssrg_path=true
		n.erase("checkpoints")

func end(id: int, time: float, p: Vector2, canceled = false) -> Dictionary:
	if not gestures.has(id): return {}
	move(id, time, p)
	var g: Dictionary = gestures[id]; gestures.erase(id)
	if canceled: return {}
	var n: Dictionary = g.note
	n.kind = g.tool
	if g.tool == "auto":
		var allowed: Array = g.allowed
		var displacement: Vector2 = p - g.start
		var swipe = maxf(absf(displacement.x), absf(displacement.y)) >= .035 and (absf(displacement.x) > absf(displacement.y) or displacement.y < 0)
		if "flick" in allowed and n.duration <= .30 and swipe: n.kind = "flick"
		elif "slide" in allowed and n.duration >= .04 and g.max_delta >= .8: n.kind = "slide"
		elif "hold" in allowed and n.duration >= .14: n.kind = "hold"
		elif "tap" in allowed and n.duration < .14: n.kind = "tap"
		elif "hold" in allowed and n.duration >= .14: n.kind = "hold"
		elif "slide" in allowed and n.duration >= .04 and g.max_delta >= .8: n.kind = "slide"
		else: return {}
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
			n.path=snap_path(g.samples,float(n.duration))
			n.ssrg_path=true
			n.erase("checkpoints")
			n.end_lane = int(n.path[-1].lane)
	if n.kind!="slide":n.erase("ssrg_path");n.erase("checkpoints")
	notes.append(n); space_chord(n,g.get("fixed",[])); return n

# Finger samples only locate meaningful turns. The saved trail consists of
# straight spans; it does not trace easing or small side-to-side finger motion.
const TURN_LANES=.8
const MOVE_LANES=.5

static func snap_path(path:Array,duration:float)->Array:
	if path.is_empty():return []
	var points:Array=[]
	for point in path:
		var at=clampf(float(point.offset),0,duration)
		var value=clampf(float(point.lane),0,SynkChart.MAX_LANE)
		if not points.is_empty() and at<=float(points[-1].offset):continue
		points.append({"offset":at,"lane":value})
	if points.is_empty():return []
	points[0].offset=0.0;points[0].lane=float(roundi(points[0].lane))
	if float(points[-1].offset)<duration:points.append({"offset":duration,"lane":points[-1].lane})
	points[-1].lane=float(roundi(points[-1].lane))
	# Reject one-event spikes, but retain a real apex even when the finger reverses
	# direction within a few frames. SSRG's authored chains can turn in about 60 ms.
	var filtered=points.duplicate(true)
	for i in range(1,points.size()-1):
		if float(points[i+1].offset)-float(points[i-1].offset)>.08:continue
		var before=float(points[i-1].lane);var current=float(points[i].lane);var after=float(points[i+1].lane)
		var spike=absf(current-(before+after)*.5)
		if absf(before-after)<.22 and spike>.45 and spike<.75:
			filtered[i].lane=(before+after)*.5
	var keep={0:true,filtered.size()-1:true}
	var direction=0
	var extreme=0
	for i in range(1,filtered.size()):
		var value=float(filtered[i].lane)
		var peak=float(filtered[extreme].lane)
		if direction==0:
			var delta=value-float(filtered[0].lane)
			if absf(delta)>=MOVE_LANES:
				direction=1 if delta>0 else -1
				extreme=i
		elif direction>0:
			if value>peak:extreme=i
			elif peak-value>=TURN_LANES:
				keep[extreme]=true;direction=-1;extreme=i
		elif value<peak:extreme=i
		elif value-peak>=TURN_LANES:
			keep[extreme]=true;direction=1;extreme=i
	# A genuine stationary lead-in or tail-out gets a corner too.
	for i in range(1,filtered.size()-1):
		if absf(float(filtered[i].lane)-float(filtered[0].lane))<MOVE_LANES:continue
		var still=i-1
		while still>0 and absf(float(filtered[still].lane)-float(filtered[0].lane))>.15:still-=1
		if float(filtered[still].offset)>=.12:keep[still]=true
		break
	for i in range(filtered.size()-2,0,-1):
		if absf(float(filtered[i].lane)-float(filtered[-1].lane))<MOVE_LANES:continue
		var still=i+1
		while still<filtered.size()-1 and absf(float(filtered[still].lane)-float(filtered[-1].lane))>.15:still+=1
		if duration-float(filtered[still].offset)>=.12:keep[still]=true
		break
	var result:Array=[]
	for i in filtered.size():
		if not keep.has(i):continue
		var point:Dictionary=filtered[i]
		var nearest=float(roundi(point.lane))
		if absf(point.lane-nearest)<=.22:point.lane=nearest
		result.append(point)
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
