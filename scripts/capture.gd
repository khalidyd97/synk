class_name SynkCapture
extends RefCounted

var gestures: Dictionary = {}
var notes: Array = []
var minimum_lane_gap=2.4
var chord_starts: Array=[]
var last_spacing_resolved=true
var onset_bounds=Vector2(0,INF)
const CHORD_WINDOW=.06

# Lane assist (Settings > Editor preferences > Recording): while a staircase is being played,
# a touch that lands between two lanes takes the one that continues it. A touch placed
# clearly on a lane is never changed.
var lane_assist = false
var onsets: Array = []        # the last two note starts: {time, lane}
const ASSIST_GAP = .6         # seconds: only notes played in a run count as a staircase
const ASSIST_EDGE = .22       # how close to the middle of a lane a touch must be to be left alone
func assisted_lane(raw: float, nearest: int, time: float) -> int:
	if not lane_assist or onsets.size() < 2: return nearest
	var before: Dictionary = onsets[0]; var last: Dictionary = onsets[1]
	var step = int(last.lane) - int(before.lane)
	if absi(step) != 1 or time - float(last.time) > ASSIST_GAP or float(last.time) - float(before.time) > ASSIST_GAP: return nearest
	if absf(raw - nearest) <= ASSIST_EDGE: return nearest
	var next = int(last.lane) + step
	if next < 0 or next > SynkChart.MAX_LANE or absf(raw - next) > .85: return nearest
	return next

static func lane(x: float) -> float:
	return clampf((x - .07) / .86 * SynkChart.LANES - .5, 0, SynkChart.MAX_LANE)

func begin(id: int, time: float, p: Vector2, tool = "auto",fixed: Array=[], allowed_types: Array=[]) -> bool:
	if time < 0 or p.x < .07 or p.x > .93 or p.y < .6 or p.y > .92 or gestures.has(id): return false
	var note_lane = roundi(lane(p.x))
	note_lane = assisted_lane(lane(p.x), note_lane, time)
	onsets.append({"time": time, "lane": note_lane})
	if onsets.size() > 2: onsets.pop_front()
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
	if n.duration>float(samples[-1].offset)+.0001:
		# A resting finger sends nothing. After a silence, note that it stayed where it was
		# until just before this event, so the rest keeps its true length.
		if n.duration-float(samples[-1].offset)>REST_GAP:samples.append({"offset":n.duration-.016,"lane":float(samples[-1].lane)})
		samples.append({"offset":n.duration,"lane":mapped_lane})
	elif samples.size()>1:samples[-1].lane=mapped_lane
	n.kind = str(g.tool) if g.tool in ["hold","slide"] else ("slide" if g.max_delta>=.8 else "hold")
	if n.kind=="slide" and n.duration>.04:
		n.path=snap_path(samples,n.duration);n.ssrg_path=true
		SynkChart.sync_connectors(n)

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
		# A flick is a hard upward swipe only (up clearly dominates sideways motion).
		var swipe = (-displacement.y) >= .05 and (-displacement.y) > absf(displacement.x) * 1.8
		if "flick" in allowed and n.duration <= .30 and swipe: n.kind = "flick"
		elif "slide" in allowed and n.duration >= .04 and g.max_delta >= .8: n.kind = "slide"
		elif "hold" in allowed and n.duration >= .14: n.kind = "hold"
		elif "tap" in allowed and n.duration < .14: n.kind = "tap"
		elif "hold" in allowed and n.duration >= .14: n.kind = "hold"
		elif "slide" in allowed and n.duration >= .04 and g.max_delta >= .8: n.kind = "slide"
		else: return {}
	if n.kind=="flick":
		var displacement: Vector2=p-g.start
		# Up-only: a flick must be a hard upward swipe, never a sideways or downward one.
		if (-displacement.y)<.05 or (-displacement.y)<=absf(displacement.x)*1.8: return {}
		n.direction=0
	if n.kind in ["tap","flick"]: n.duration = 0.0; n.path = []; n.end_lane = n.lane
	else:
		if n.duration < .04: return {}
		if n.kind == "hold": n.end_lane = n.lane; n.path = []
		else:
			n.path=snap_path(g.samples,float(n.duration))
			n.ssrg_path=true
			SynkChart.sync_connectors(n)
			n.end_lane = int(n.path[-1].lane)
	if n.kind!="slide":n.erase("ssrg_path");n.erase("checkpoints")
	notes.append(n); space_chord(n,g.get("fixed",[])); return n

# --- The shape of a recorded slide ----------------------------------------------------------
# A slide is saved as a few points joined by straight spans. Between two points the finger is
# taken to make one move: anything from a steady glide to the natural "start slowly, speed
# up, slow down" of a hand. A point is added only where the finger did something a single
# move cannot explain by more than SLIDE_FIT lanes: it turned round, or it stayed put and
# then went on. So the same gesture gives the same shape however the finger eased into it,
# and small differences in the touch samples do not add or remove corners.
const SLIDE_FIT=.4
# ... or by being this many seconds early or late: a fast move covers a lane in a few
# milliseconds, so its exact timing is not a shape.
const SLIDE_SLACK=.04
# A move that does nearly all of its travelling in under this share of its time is a step:
# the finger waited, crossed over quickly, and waited again. (An eased move takes over half.)
const STEP_SHARE=.35
# Points this close in lane are the two ends of a rest: a flat run.
const FLAT_LANES=.4
# A rest part-way along a move: the finger stays within REST_LANES for at least REST_TIME,
# and at the pace of the whole move it would have gone REST_MISSED lanes further meanwhile.
const REST_LANES=.18
const REST_TIME=.08
const REST_MISSED=.45
# A finger pauses for a moment as it lands and again before it lifts. That is part of making
# the swipe, not a rest: at the very start or end of a slide only a longer pause is one.
const REST_EDGE_TIME=.16
# A slide shorter than this is one swipe: it has turns, but no rests.
const SWIPE_TIME=.3
# A resting finger sends nothing: a silence this long in the samples was a rest.
const REST_GAP=.08
# A corner this close to the straight line between its neighbours is dropped.
const REST_BEND=.3

static func eased(t:float)->float:return t*t*t*(10.0+t*(6.0*t-15.0))
# How far sample k lies outside a single move from sample a to sample b (signed, in lanes).
static func off_move(points:Array,a:int,b:int,k:int)->float:
	var span=maxf(.0001,float(points[b].offset)-float(points[a].offset))
	var at=float(points[k].offset)-float(points[a].offset)
	var early=clampf((at-SLIDE_SLACK)/span,0,1);var late=clampf((at+SLIDE_SLACK)/span,0,1)
	var from=float(points[a].lane);var to=float(points[b].lane)
	var ends=[lerpf(from,to,early),lerpf(from,to,eased(early)),lerpf(from,to,late),lerpf(from,to,eased(late))]
	var value=float(points[k].lane)
	if value>float(ends.max()):return value-float(ends.max())
	if value<float(ends.min()):return value-float(ends.min())
	return 0.0
# Marks the samples between a and b that one move cannot explain.
static func fit_moves(points:Array,a:int,b:int,keep:Dictionary)->void:
	if b-a<2:return
	var worst=0.0;var at=-1
	for k in range(a+1,b):
		var off=absf(off_move(points,a,b,k))
		if off>worst:worst=off;at=k
	if worst<SLIDE_FIT:
		fit_step(points,a,b,keep);return
	# A rest is equally far off all along: take its middle, so the split does not depend on
	# which sample happened to be a hair further out.
	var side=signf(off_move(points,a,b,at));var first=at;var last=at
	while first-1>a and off_move(points,a,b,first-1)*side>=worst-.12:first-=1
	while last+1<b and off_move(points,a,b,last+1)*side>=worst-.12:last+=1
	var middle=(float(points[first].offset)+float(points[last].offset))*.5
	for k in range(first,last+1):
		if absf(float(points[k].offset)-middle)<absf(float(points[at].offset)-middle):at=k
	keep[at]=true
	fit_moves(points,a,at,keep);fit_moves(points,at,b,keep)

# Marks where the finger left and where it arrived, if the move from a to b is a step.
static func fit_step(points:Array,a:int,b:int,keep:Dictionary)->void:
	var from=float(points[a].lane);var travel=float(points[b].lane)-from
	if absf(travel)<.7:return
	var left=a;var arrived=b;var moving=false
	for k in range(a+1,b):
		var progress=(float(points[k].lane)-from)/travel
		if not moving and progress<=.1:left=k
		elif progress>.1:moving=true
		if progress>=.9:arrived=k;break
	var span=float(points[b].offset)-float(points[a].offset)
	if float(points[arrived].offset)-float(points[left].offset)>=span*STEP_SHARE:
		fit_rest(points,a,b,keep);return
	keep[left]=true;keep[arrived]=true

# Marks the longest rest part-way along the move from a to b (a staircase has one per step),
# then looks at the two moves on either side of it.
static func fit_rest(points:Array,a:int,b:int,keep:Dictionary)->void:
	var from=float(points[a].lane);var to=float(points[b].lane)
	var pace=absf(to-from)/maxf(.0001,float(points[b].offset)-float(points[a].offset))
	if pace*REST_TIME<.01:return
	var best=0.0;var best_first=-1;var best_last=-1
	var first=a+1
	while first<b:
		var low=float(points[first].lane);var high=low;var last=first
		while last+1<b:
			var next=float(points[last+1].lane)
			if maxf(high,next)-minf(low,next)>REST_LANES:break
			low=minf(low,next);high=maxf(high,next);last+=1
		var length=float(points[last].offset)-float(points[first].offset)
		var level=(low+high)*.5
		if length>best and length>=REST_TIME and length*pace>=REST_MISSED and absf(level-from)>FLAT_LANES and absf(level-to)>FLAT_LANES:
			best=length;best_first=first;best_last=last
		first+=1
	if best_first<0:return
	keep[best_first]=true;keep[best_last]=true
	fit_moves(points,a,best_first,keep);fit_moves(points,best_last,b,keep)

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
	fit_moves(filtered,0,filtered.size()-1,keep)
	var kept:Array=keep.keys();kept.sort()
	var result:Array=[]
	for index in kept:result.append({"offset":float(filtered[index].offset),"lane":float(filtered[index].lane)})
	# Level the rests: neighbouring points on (nearly) the same lane become a flat run on one
	# lane: the slide's own first or last lane, or the lane the finger lay on.
	var start=0
	while start<result.size():
		var stop=start
		while stop+1<result.size() and absf(float(result[stop+1].lane)-float(result[start].lane))<=FLAT_LANES:stop+=1
		var level=0.0
		for i in range(start,stop+1):level+=float(result[i].lane)
		level/=stop-start+1
		if start==0:level=float(result[0].lane)
		elif stop==result.size()-1:level=float(result[-1].lane)
		elif absf(level-roundf(level))<=.3:level=roundf(level)
		elif stop==start:
			# A turn: the finger went a little past the last sample before it came back.
			var outward=signf(level-float(result[start-1].lane))
			var beyond=ceilf(level) if outward>0 else floorf(level)
			if absf(beyond-level)<=.45:level=beyond
		for i in range(start,stop+1):result[i].lane=level
		# Only the two ends of a flat run are corners.
		while stop-start>1:result.remove_at(start+1);stop-=1
		start=stop+1
	# Rests too short to mean anything. At an end of the slide the pause is the landing or the
	# lift; in the middle it is a turn.
	var changed=true
	while changed:
		changed=false
		for i in result.size()-1:
			if float(result[i].lane)!=float(result[i+1].lane):continue
			var length=float(result[i+1].offset)-float(result[i].offset)
			if i==0 and i+1==result.size()-1:break
			if i==0:
				if length<REST_EDGE_TIME or duration<SWIPE_TIME:result.remove_at(1);changed=true;break
			elif i+1==result.size()-1:
				if length<REST_EDGE_TIME or duration<SWIPE_TIME:result.remove_at(i);changed=true;break
			elif length<REST_TIME or duration<SWIPE_TIME:
				result[i].offset=(float(result[i].offset)+float(result[i+1].offset))*.5
				result.remove_at(i+1);changed=true;break
	# Drop corners that barely bend the trail, the least significant first.
	while result.size()>2:
		var weakest=-1;var weakest_bend=REST_BEND
		for k in range(1,result.size()-1):
			var before:Dictionary=result[k-1];var after:Dictionary=result[k+1];var here:Dictionary=result[k]
			var along=(float(here.offset)-float(before.offset))/maxf(.0001,float(after.offset)-float(before.offset))
			var bend=absf(float(here.lane)-lerpf(float(before.lane),float(after.lane),along))
			if bend<weakest_bend:weakest_bend=bend;weakest=k
		if weakest<0:break
		result.remove_at(weakest)
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
