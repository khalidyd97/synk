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
# flat runs get FLAT_STEP each. M, N and W need a stroke that runs back in time, which
# would take three or four slides, so they are left to the typed TEXT tool. The two
# slides never start together on one spot: the second one's head always has room to be hit.
const SHAPES = {
	"0": [[[3,0],[1,0],[0,1],[0,5],[2,6]], [[4,1],[4,5],[2,6]]],
	"1": [[[1,0],[3,0],[2,0],[2,6]], [[1,4.6],[2,6]]],
	"2": [[[4,0],[0,0],[4,4],[4,5],[3,6],[1,6]], [[0,5],[1,6]]],
	"3": [[[0,0],[3,0],[4,1],[4,2],[3,3],[1,3]], [[4,4],[4,5],[3,6],[0,6]]],
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
	"E": [[[4,0],[0,0],[0,6],[4,6]], [[1,3],[3,3]]],
	"F": [[[0,0],[0,6],[4,6]], [[1,3],[3,3]]],
	"G": [[[3,0],[1,0],[0,1],[0,5],[1,6],[4,6]], [[4,1],[4,3],[2,3]]],
	"H": [[[0,0],[0,3],[4,3],[4,6]], [[4,0],[4,3],[0,3],[0,6]]],
	"I": [[[1,0],[3,0],[2,0],[2,6],[1,6],[3,6]]],
	"J": [[[1,0],[3,0],[4,1],[4,6],[2,6]], [[0,.5],[0,1.5]]],
	"K": [[[0,0],[0,6]], [[4,0],[0,3],[4,6]]],
	"L": [[[4,0],[0,0],[0,6]]],
	"O": [[[3,0],[1,0],[0,1.5],[0,4.5],[2,6]], [[4,1.5],[4,4.5],[2,6]]],
	"P": [[[0,0],[0,6],[3,6]], [[1,3],[3,3],[4,4],[4,5],[3,6]]],
	"Q": [[[2,0],[0,1.5],[0,4.5],[2,6]], [[4,0],[3,1],[4,2],[4,4.5],[2,6]]],
	"R": [[[0,0],[0,6],[3,6]], [[4,0],[1,3],[3,3],[4,4],[4,5],[3,6]]],
	"S": [[[0,0],[3,0],[4,1],[4,2],[3,3],[1,3],[0,4],[0,5],[1,6],[4,6]]],
	"T": [[[2,0],[2,6],[0,6],[4,6]]],
	"U": [[[3,0],[1,0],[0,1],[0,6]], [[4,1],[4,6]]],
	"V": [[[2,0],[0,6]], [[2.5,1.5],[4,6]]],
	"X": [[[0,0],[4,6]], [[4,0],[0,6]]],
	"Y": [[[2,0],[2,3],[4,6]], [[1.5,3.75],[0,6]]],
	"Z": [[[4,0],[0,0],[4,6],[0,6]]],
}
const SHAPE_ORDER = "0123456789ABCDEFGHIJKLOPQRSTUVXYZ"

# Replaces one hold with its character: the slides fill the hold's own time (start to
# end) and sit width lanes wide around its lane, kept inside lanes 1-13.
static func shape_notes(character: String, start_time: float, duration: float, centre_lane: float, width: float = 8.0) -> Array:
	var key = character.to_upper()
	if not SHAPES.has(key): return []
	var strokes: Array = SHAPES[key]
	# Flat steps add time, so the grid gets what is left of the hold after the longest run of them.
	var most_flats = 0
	for stroke in strokes:
		var flats = 0
		for i in range(1, stroke.size()):
			if is_equal_approx(float(stroke[i][1]), float(stroke[i - 1][1])): flats += 1
		most_flats = maxi(most_flats, flats)
	var height = maxf(.3, duration - most_flats * FLAT_STEP)
	var left = clampf(centre_lane - width * .5, 0.0, float(SynkChart.MAX_LANE) - width)
	var notes: Array = []
	for stroke in strokes:
		var points: Array = []
		for p in stroke:
			var v = Vector2(float(p[0]), float(p[1]))
			if points.is_empty() or not points[-1].is_equal_approx(v): points.append(v)
		notes.append(piece_note(points, start_time, height, left, width))
	return notes

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
