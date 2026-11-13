extends RefCounted
# Letter and number shaped slides. Each glyph is a few strokes on a 4 x 6 grid (x = lanes
# across, y = time, y up = later, so the shape reads upright as it approaches in play).
# A slide can only move forward in time, so every stroke is cut wherever it turns back in
# time and each piece becomes its own slide. Flat strokes get a short time step.

const GRID_W = 4.0
const GRID_H = 6.0
# Seconds given to each flat (same-time) step of a stroke, so bars stay nearly level.
const FLAT_STEP = .05

const GLYPHS = {
	"0": [[[1,0],[0,1],[0,5],[1,6],[3,6],[4,5],[4,1],[3,0],[1,0]]],
	"1": [[[1,5],[2,6],[2,0]], [[1,0],[3,0]]],
	"2": [[[0,5],[1,6],[3,6],[4,5],[4,4],[0,0],[4,0]]],
	"3": [[[0,5],[1,6],[3,6],[4,5],[4,4],[3,3],[1,3]], [[3,3],[4,2],[4,1],[3,0],[1,0],[0,1]]],
	"4": [[[3,0],[3,6],[0,2],[4,2]]],
	"5": [[[4,6],[0,6],[0,3],[3,3],[4,2],[4,1],[3,0],[0,0]]],
	"6": [[[3,6],[1,6],[0,5],[0,1],[1,0],[3,0],[4,1],[4,2],[3,3],[0,3]]],
	"7": [[[0,6],[4,6],[1,0]]],
	"8": [[[1,3],[0,4],[0,5],[1,6],[3,6],[4,5],[4,4],[3,3],[1,3],[0,2],[0,1],[1,0],[3,0],[4,1],[4,2],[3,3]]],
	"9": [[[4,3],[1,3],[0,4],[0,5],[1,6],[3,6],[4,5],[4,1],[3,0],[1,0]]],
	"A": [[[0,0],[2,6],[4,0]], [[1,3],[3,3]]],
	"B": [[[0,0],[0,6],[3,6],[4,5],[4,4],[3,3],[0,3]], [[3,3],[4,2],[4,1],[3,0],[0,0]]],
	"C": [[[4,5],[3,6],[1,6],[0,5],[0,1],[1,0],[3,0],[4,1]]],
	"D": [[[0,0],[0,6],[2,6],[4,4],[4,2],[2,0],[0,0]]],
	"E": [[[4,6],[0,6],[0,0],[4,0]], [[0,3],[3,3]]],
	"F": [[[4,6],[0,6],[0,0]], [[0,3],[3,3]]],
	"G": [[[4,5],[3,6],[1,6],[0,5],[0,1],[1,0],[3,0],[4,1],[4,3],[2,3]]],
	"H": [[[0,0],[0,6]], [[4,0],[4,6]], [[0,3],[4,3]]],
	"I": [[[1,6],[3,6]], [[2,6],[2,0]], [[1,0],[3,0]]],
	"J": [[[1,6],[4,6]], [[3,6],[3,1],[2,0],[1,0],[0,1]]],
	"K": [[[0,0],[0,6]], [[4,6],[0,2]], [[1,3],[4,0]]],
	"L": [[[0,6],[0,0],[4,0]]],
	"M": [[[0,0],[0,6],[2,3],[4,6],[4,0]]],
	"N": [[[0,0],[0,6],[4,0],[4,6]]],
	"O": [[[1,0],[0,1],[0,5],[1,6],[3,6],[4,5],[4,1],[3,0],[1,0]]],
	"P": [[[0,0],[0,6],[3,6],[4,5],[4,4],[3,3],[0,3]]],
	"Q": [[[1,0],[0,1],[0,5],[1,6],[3,6],[4,5],[4,1],[3,0],[1,0]], [[2,2],[4,0]]],
	"R": [[[0,0],[0,6],[3,6],[4,5],[4,4],[3,3],[0,3]], [[2,3],[4,0]]],
	"S": [[[4,5],[3,6],[1,6],[0,5],[0,4],[1,3],[3,3],[4,2],[4,1],[3,0],[1,0],[0,1]]],
	"T": [[[0,6],[4,6]], [[2,6],[2,0]]],
	"U": [[[0,6],[0,1],[1,0],[3,0],[4,1],[4,6]]],
	"V": [[[0,6],[2,0],[4,6]]],
	"W": [[[0,6],[1,0],[2,4],[3,0],[4,6]]],
	"X": [[[0,0],[4,6]], [[0,6],[4,0]]],
	"Y": [[[0,6],[2,3],[4,6]], [[2,3],[2,0]]],
	"Z": [[[0,6],[4,6],[0,0],[4,0]]],
}

# Shapes for turning one recorded hold into a character: at most two slides each. Every
# stroke already runs forward in time (y never drops), so each stroke is exactly one slide;
# flat runs get the time a finger needs to follow them. M, N and W need a stroke that runs back in time, which
# would take three or four slides, so they are left to the typed TEXT tool. The two
# slides never start together on one spot: the second one's head always has room to be hit.
const SHAPES = {
	"0": [[[3,0],[1,0],[0,1],[0,5],[2,6]], [[4,1],[4,5],[2,6]]],
	"1": [[[1,0],[3,0],[2,0],[2,6]], [[1,4.6],[2,6]]],
	"2": [[[4,0],[0,0],[4,4],[4,5],[3,6],[1,6]], [[0,5],[1,6]]],
	"3": [[[0,0],[3,0],[4,1],[4,2],[3,3],[1.5,3],[3,3],[4,4],[4,5],[3,6],[0,6]]],
	"4": [[[3,0],[3,6]], [[4,2],[0,2],[3,6]]],
	"5": [[[0,0],[3,0],[4,1],[4,2],[3,3],[0,3],[0,6],[4,6]]],
	"6": [[[3,0],[1,0],[0,1],[0,5],[1,6],[4,6]], [[4,1],[4,2],[3,3],[0,3]]],
	"7": [[[1,0],[4,6],[0,6]]],
	"8": [[[3,0],[1,0],[0,1],[0,2],[4,4],[4,5],[2,6]], [[4,1],[4,2],[0,4],[0,5],[2,6]]],
	"9": [[[0,0],[3,0],[4,1],[4,5],[2,6]], [[3,3],[1,3],[0,4],[0,5],[2,6]]],
	"A": [[[0,0],[1,3],[3,3],[2,6]], [[4,0],[3,3],[1,3],[2,6]]],
	"B": [[[3,0],[0,0],[0,6]], [[4,1],[4,2],[3,3],[1,3],[3,3],[4,4],[4,5],[3,6],[0,6]]],
	"C": [[[4,0],[1,0],[0,1],[0,5],[1,6],[4,6]]],
	"D": [[[2,0],[0,0],[0,6]], [[3,1],[4,2],[4,4],[2,6],[0,6]]],
	"E": [[[4,0],[0,0],[0,6],[4,6]], [[1.5,3],[3.5,3]]],
	"F": [[[0,0],[0,6],[4,6]], [[1.5,3],[3.5,3]]],
	"G": [[[3,0],[1,0],[0,1],[0,5],[1,6],[4,6]], [[4,1],[4,3],[2,3]]],
	"H": [[[0,0],[0,3],[4,3],[4,6]], [[4,0],[4,3],[0,3],[0,6]]],
	"I": [[[1,0],[2,0],[2,6],[3,6]]],
	"J": [[[1,0],[3,0],[4,1],[4,6],[2,6]], [[0,.5],[0,1.5]]],
	"K": [[[0,0],[0,6]], [[4,0],[0,3],[4,6]]],
	"L": [[[4,0],[0,0],[0,6]]],
	"O": [[[3,0],[1,0],[0,1.5],[0,4.5],[2,6]], [[4,1.5],[4,4.5],[2,6]]],
	"P": [[[0,0],[0,6],[3,6]], [[1,3],[3,3],[4,4],[4,5],[3,6]]],
	"Q": [[[2,0],[0,1.5],[0,4.5],[2,6]], [[4,0],[3,1],[4,2],[4,4.5],[2,6]]],
	"R": [[[0,0],[0,6],[3,6]], [[4,0],[1,3],[3,3],[4,4],[4,5],[3,6]]],
	"S": [[[0,0],[3,0],[4,1],[4,2],[3,3],[1,3],[0,4],[0,5],[1,6],[4,6]]],
	"T": [[[2,0],[2,5],[0,6]], [[2.8,5.4],[4,6]]],
	"U": [[[3,0],[1,0],[0,1],[0,6]], [[4,1],[4,6]]],
	"V": [[[2,0],[0,6]], [[2.5,1.5],[4,6]]],
	"X": [[[0,0],[4,6]], [[4,0],[0,6]]],
	"Y": [[[2,0],[2,3],[4,6]], [[1.5,3.75],[0,6]]],
	"Z": [[[4,0],[0,0],[4,6],[0,6]]],
}
const SHAPE_ORDER = "0123456789ABCDEFGHIJKLOPQRSTUVXYZ"

# Replaces one hold with its character: the slides start with the hold, fill its time
# (at least MIN_SHAPE_TIME) and sit up to width lanes wide around its lane, inside lanes 1-13.
static func shape_notes(character: String, start_time: float, duration: float, centre_lane: float, width: float = 8.0) -> Array:
	var key = character.to_upper()
	if not SHAPES.has(key): return []
	var strokes: Array = SHAPES[key]
	duration = maxf(duration, MIN_SHAPE_TIME)
	# Every move gets at least the time a finger needs to follow it (FOLLOW_SPEED), so bars
	# lean a little instead of jumping. The letter's height is then the largest that still
	# fits the hold; when even the smallest height does not fit, the letter gets narrower.
	var w = width
	var height = duration
	while true:
		var lo = 0.0; var hi = duration
		for i in 24:
			var mid = (lo + hi) * .5
			if shape_length(strokes, mid, w) <= duration: lo = mid
			else: hi = mid
		height = lo
		if height >= duration * MIN_UPRIGHT or w <= MIN_SHAPE_WIDTH: break
		w = maxf(MIN_SHAPE_WIDTH, w - 1.0)
	# Too short a hold would squash the letter flat: it keeps a readable height and runs on
	# past the hold's end instead.
	height = maxf(height, MIN_HEIGHT)
	var left = clampf(centre_lane - w * .5, 0.0, float(SynkChart.MAX_LANE) - w)
	var notes: Array = []
	for timeline in shape_timelines(strokes, height, w):
		var lanes: Array = []; var offsets: Array = []
		for i in timeline.size():
			lanes.append(clampf(left + float(timeline[i].x) / GRID_W * w, 0.0, float(SynkChart.MAX_LANE)))
			offsets.append(float(timeline[i].t))
		var n = SynkChart.note(start_time + offsets[0], roundi(lanes[0]), "slide")
		n.duration = offsets[-1] - offsets[0]
		n.ssrg_path = true
		var path: Array = []
		for i in lanes.size(): path.append({"offset": offsets[i] - offsets[0], "lane": lanes[i]})
		n.path = path; n.end_lane = roundi(lanes[-1])
		notes.append(n)
	return notes

# Fastest sideways move a shape asks of a finger, in lanes per second.
const FOLLOW_SPEED = 28.0
# Shapes always last at least this long, even from a very short hold.
const MIN_SHAPE_TIME = .8
# Fraction of the time the letter's upright strokes keep before it is made narrower.
const MIN_UPRIGHT = .45
const MIN_SHAPE_WIDTH = 6.0
# Seconds of upright travel every letter keeps, so it still reads as its shape.
const MIN_HEIGHT = .55
# Every slide of a shape lasts at least this long, so its head and end are two clear moments.
const MIN_STROKE_TIME = .25
# A stroke that starts above where the first one ends waits this long after it, to re-tap.
const RETAP_TIME = .15

# The points of one stroke with their times from the shape's start: each move takes as long
# as its rise in the grid, or as long as the finger needs to cross its lanes, whichever is longer.
static func stroke_timeline(stroke: Array, height: float, width: float) -> Array:
	var result: Array = []
	var t = float(stroke[0][1]) / GRID_H * height
	for i in stroke.size():
		var p = stroke[i]
		if i > 0:
			var q = stroke[i - 1]
			if is_equal_approx(float(p[0]), float(q[0])) and is_equal_approx(float(p[1]), float(q[1])): continue
			var rise = (float(p[1]) - float(q[1])) / GRID_H * height
			var across = absf(float(p[0]) - float(q[0])) / GRID_W * width / FOLLOW_SPEED
			t += maxf(maxf(rise, across), .02)
		result.append({"x": float(p[0]), "y": float(p[1]), "t": t})
	return result

# All strokes of a shape. The first stroke's sideways moves slow it down, so a later stroke
# starts no earlier than the first one reaches its height (or ends, if it never does). The
# shape stays in proportion and the second head never lands beside a finger still on its way.
static func shape_timelines(strokes: Array, height: float, width: float) -> Array:
	var result: Array = []
	for stroke in strokes:
		var timeline = stroke_timeline(stroke, height, width)
		var own = float(timeline[-1].t) - float(timeline[0].t)
		if own < MIN_STROKE_TIME:
			for point in timeline: point.t = float(timeline[0].t) + (float(point.t) - float(timeline[0].t)) * MIN_STROKE_TIME / maxf(own, .001) if own > 0.0 else float(point.t)
		if not result.is_empty():
			var first: Array = result[0]
			var reach = time_at_height(first, float(timeline[0].y))
			if float(timeline[0].y) > float(first[-1].y): reach = float(first[-1].t) + RETAP_TIME
			var shift = maxf(0.0, reach - float(timeline[0].t))
			for point in timeline: point.t = float(point.t) + shift
		result.append(timeline)
	return result

static func time_at_height(timeline: Array, y: float) -> float:
	for i in timeline.size():
		if float(timeline[i].y) >= y:
			if i == 0: return float(timeline[0].t)
			var a = timeline[i - 1]; var b = timeline[i]
			var span = float(b.y) - float(a.y)
			return lerpf(float(a.t), float(b.t), 0.0 if span <= 0.0 else (y - float(a.y)) / span)
	return float(timeline[-1].t)

static func shape_length(strokes: Array, height: float, width: float) -> float:
	var longest = 0.0
	for timeline in shape_timelines(strokes, height, width):
		longest = maxf(longest, float(timeline[-1].t))
	return longest

static func supported(character: String) -> bool:
	return GLYPHS.has(character.to_upper())

# Characters of text that can be drawn (spaces kept as gaps).
static func clean(text: String) -> String:
	var result = ""
	for character in text.to_upper():
		if character == " " or GLYPHS.has(character): result += character
	return result.strip_edges()

# Splits a stroke into pieces that only move one way in time, each running forward in time.
static func monotonic_pieces(stroke: Array) -> Array:
	var points: Array = []
	for p in stroke:
		var v = Vector2(float(p[0]), float(p[1]))
		if points.is_empty() or not points[-1].is_equal_approx(v): points.append(v)
	var pieces: Array = []
	if points.size() == 1: return [points]
	var piece: Array = [points[0]]; var direction = 0
	for i in range(1, points.size()):
		var dy = points[i].y - points[i - 1].y
		var step = 0 if is_zero_approx(dy) else (1 if dy > 0 else -1)
		if step == 0 or direction == 0 or step == direction:
			piece.append(points[i])
			if step != 0: direction = step
		else:
			pieces.append([piece, direction])
			piece = [points[i - 1], points[i]]; direction = step
	pieces.append([piece, direction])
	var result: Array = []
	for entry in pieces:
		var ordered: Array = entry[0].duplicate()
		if entry[1] < 0: ordered.reverse()
		result.append(ordered)
	return result

# Notes for text starting at start_time. Each glyph is height seconds tall and width lanes
# wide, centred on centre_lane; glyphs follow one another in time with gap seconds between.
static func build(text: String, start_time: float, height: float, centre_lane: float = 6.0, width: float = 8.0, gap: float = -1.0) -> Array:
	var notes: Array = []
	if gap < 0: gap = height * .4
	var left = clampf(centre_lane - width * .5, 0.0, float(SynkChart.MAX_LANE) - width)
	var at = start_time
	for character in clean(text):
		if character == " ":
			at += height * .6; continue
		for stroke in GLYPHS[character]:
			for piece in monotonic_pieces(stroke):
				notes.append(piece_note(piece, at, height, left, width))
		at += height + gap
	return notes

static func piece_note(piece: Array, glyph_start: float, height: float, left: float, width: float) -> Dictionary:
	var lane_of = func(x: float) -> float: return clampf(left + x / GRID_W * width, 0.0, float(SynkChart.MAX_LANE))
	if piece.size() == 1:
		return SynkChart.note(glyph_start + piece[0].y / GRID_H * height, roundi(lane_of.call(piece[0].x)), "tap")
	var times: Array = []; var flat = 0.0
	for i in piece.size():
		if i > 0 and is_equal_approx(piece[i].y, piece[i - 1].y): flat += FLAT_STEP
		times.append(glyph_start + piece[i].y / GRID_H * height + flat)
	var note = SynkChart.note(times[0], roundi(lane_of.call(piece[0].x)), "slide")
	note.duration = times[-1] - times[0]
	note.ssrg_path = true
	var path: Array = []
	for i in piece.size(): path.append({"offset": times[i] - times[0], "lane": lane_of.call(piece[i].x)})
	note.path = path
	note.end_lane = roundi(path[-1].lane)
	# No connector caps at the bends: the trail itself draws the letter.
	return note
