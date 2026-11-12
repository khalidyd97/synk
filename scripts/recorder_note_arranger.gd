extends Control

var game: Control
var edit_mode = "shape"
var drags: Dictionary = {}
var blocked_touches: Dictionary = {}
var buttons: Dictionary = {}
var shape_buttons: Dictionary = {}
var selected_point_index = -1
var selected_note_ref: Dictionary = {}
var delete_point_button: Button
# The second and third rows stay folded away until MORE is tapped, so the panel covers less of the track.
var expanded = false
var more_button: Button
var plate: Panel
var extra_buttons: Array = []
func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Dark plate behind the hold/slide edit rows so their text never sits on the bright highway.
	plate = Panel.new();add_child(plate);plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.anchor_left = 0.132;plate.anchor_right = 0.668 + COLUMN_STEP;plate.anchor_top = 0.192;plate.anchor_bottom = 0.396
	var plate_style = StyleBoxFlat.new();plate_style.bg_color = Color(0.05, 0.05, 0.06, 0.9)
	plate_style.border_color = Color(1, 1, 1, 0.07);plate_style.set_border_width_all(1);plate_style.set_corner_radius_all(22)
	plate_style.shadow_color = Color(0, 0, 0, 0.45);plate_style.shadow_size = 18
	plate.add_theme_stylebox_override("panel", plate_style)
	# Three rows of six: tools · point and path edits · one-tap shapes.
	# Row 1: how a touch on the highway edits the note, plus snapping and point delete.
	for i in 4:
		var key = ["move", "shape", "draw", "points"][i]
		var b = tool_button(["MOVE", "SHAPE", "DRAW", "CONNECTOR"][i], 0, i)
		b.pressed.connect( func():
			edit_mode = "shape" if key == "points" else key
			game.dots_mode = key == "points" and not game.dots_mode
			game.refresh_arrange_controls())
		buttons[key] = b
	snap_button = tool_button("", 0, 4);snap_button.pressed.connect(game.cycle_slide_snap)
	delete_point_button = tool_button("DELETE POINT", 0, 5);delete_point_button.pressed.connect(delete_selected_point)
	more_button = tool_button("MORE", 0, 6);more_button.pressed.connect(func(): expanded = not expanded)
	# Row 2: the selected bend point (or the whole slide), clean-up and endpoints.
	curve_button = tool_button("CURVE", 1, 0);curve_button.pressed.connect(toggle_curve)
	for i in 2:
		var operation = "smooth" if i == 0 else "straighten"
		var b = tool_button("SIMPLIFY" if operation == "smooth" else "STRAIGHTEN", 1, 1 + i)
		b.pressed.connect( func(): reshape(operation));shape_buttons[operation] = b
	for i in 2:
		var endpoint = "start" if i == 0 else "end"
		var b = tool_button("GO " + endpoint.to_upper(), 1, 3 + i)
		b.pressed.connect( func(): focus_endpoint(endpoint))
	# Row 3: one-tap shapes, then mirror and flip, all fine-tuned afterwards by dragging.
	var preset_names = ["zigzag", "wave", "s_curve", "sweep", "mirror", "flip"]
	for i in preset_names.size():
		var preset = preset_names[i]
		var b = tool_button(["ZIGZAG", "WAVE", "S-CURVE", "SWEEP", "MIRROR", "FLIP"][i], 2, i)
		b.pressed.connect( func(): apply_preset(preset));preset_buttons[preset] = b
var snap_button: Button
var curve_button: Button
var preset_buttons: Dictionary = {}
const COLUMN_LEFT = 0.14
const COLUMN_STEP = 0.0865
func tool_button(text: String, row: int, column: int) -> Button:
	var b = preload("res://scripts/recorder_action.gd").new();b.text = text
	b.caption_size = 17;b.compact = true;b.variant = "tool";add_child(b)
	b.anchor_left = COLUMN_LEFT + column * COLUMN_STEP;b.anchor_right = b.anchor_left + COLUMN_STEP - 0.006
	b.anchor_top = 0.202 + row * 0.064;b.anchor_bottom = b.anchor_top + 0.056
	if row > 0: extra_buttons.append(b)
	return b
func focus_endpoint(kind: String) -> void :
	if not drags.is_empty(): return
	var note = selected_note()
	if note.is_empty(): return
	var at = float(note.time) + (float(note.duration) if kind == "end" else 0.0)
	game.song_time = clampf(at + 0.4, 0, game.length());game.visual_song_time = game.song_time;game.visual_clock_ready = false
	game.arrange_preview.request(at);queue_redraw()
func selected_note() -> Dictionary: return game.arrange_selection.get("note", {})
func _process(_delta: float) -> void :
	var note = selected_note()
	visible = game.mode == "record" and game.arranging and not note.is_empty() and note.kind in ["hold", "slide"]
	if not visible:
		for id in drags: game.arrange_touches.erase(id)
		for id in draw_touches: game.arrange_touches.erase(id)
		drags.clear();draw_touches.clear();blocked_touches.clear();selected_point_index = -1;selected_note_ref = {};return
	if not is_same(selected_note_ref, note):
		selected_point_index = -1
		selected_note_ref = note
	if selected_point_index >= note.path.size() - 1: selected_point_index = -1
	var writable = game.recorder.writable(note) and drags.is_empty() and draw_touches.is_empty()
	var slide = note.kind == "slide"
	plate.anchor_bottom = 0.396 if expanded else 0.268
	more_button.text = "LESS" if expanded else "MORE";more_button.set_selected(expanded)
	for b in extra_buttons: b.visible = expanded
	delete_point_button.visible = slide
	delete_point_button.disabled = selected_point_index <= 0 or not writable
	for operation in shape_buttons:
		shape_buttons[operation].visible = slide and expanded
		shape_buttons[operation].disabled = not writable or (note.path.size() <= 2 if operation == "smooth" else note.path.size() == 2)
	for key in buttons: buttons[key].set_selected(game.dots_mode if key == "points" else ( not game.dots_mode and edit_mode == key))
	snap_button.text = {"free": "SNAP · OFF", "lanes": "SNAP · LANES", "beats": "SNAP · BEATS"}[game.slide_snap]
	snap_button.set_selected(game.slide_snap != "free")
	# Curve: the selected bend point, or every bend when none is selected.
	var inner = inner_points(note)
	curve_button.visible = slide and expanded
	curve_button.disabled = not writable or inner.is_empty()
	curve_button.text = "POINT CURVE" if selected_point_index > 0 else "CURVE ALL"
	curve_button.set_selected(not inner.is_empty() and curved(note, inner))
	for preset in preset_buttons:
		preset_buttons[preset].disabled = not writable or (preset == "flip" and not slide)
	queue_redraw()
func marker_point(note: Dictionary, at: float) -> Variant:
	var w = game.field.world
	var z = (at - game.song_time) * w.travel_speed()
	if not w.depth_visible(z) or z > 1.5: return null
	var point = Vector3(w.note_x(SynkChart.lane_at(note, at)), w.trail_height() + 0.07, z)
	if w.camera.is_position_behind(point): return null
	var normalized = w.camera.unproject_position(w.warp_point(point)) / Vector2(game.field.viewport.size)
	var screen = game.field.get_global_transform_with_canvas() * (normalized * game.field.size)
	return get_global_transform_with_canvas().affine_inverse() * screen
func handles() -> Array:
	var result: Array = []; var note = selected_note()
	if note.is_empty() or note.kind not in ["hold", "slide"]: return result
	for kind in ["start", "end"]:
		var at = float(note.time) + (float(note.duration) if kind == "end" else 0.0)
		var point = marker_point(note, at)
		if point != null: result.append({"kind": kind, "index": -1, "position": point, "at": at})
	if note.kind == "slide":
		var last = Vector2(-10000, -10000); var count = 0
		for i in range(1, note.path.size() - 1):
			var at = float(note.time) + float(note.path[i].offset); var point = marker_point(note, at)
			if point == null or point.distance_to(last) < 42: continue
			if result.any( func(handle): return handle.position.distance_to(point) < 30): continue
			result.append({"kind": "point", "index": i, "position": point, "at": at});last = point;count += 1
			if count >= 24: break
	return result
var draw_touches: Dictionary = {}
# Screen position of a (time, lane) point on the recorder highway, or null when off screen.
func screen_point(at: float, lane: float) -> Variant:
	var w = game.field.world
	var z = (at - game.song_time) * w.travel_speed()
	if not w.depth_visible(z) or z > 1.5: return null
	var point = Vector3(w.note_x(lane), w.trail_height() + 0.07, z)
	if w.camera.is_position_behind(point): return null
	var normalized = w.camera.unproject_position(w.warp_point(point)) / Vector2(game.field.viewport.size)
	var screen = game.field.get_global_transform_with_canvas() * (normalized * game.field.size)
	return get_global_transform_with_canvas().affine_inverse() * screen
func _draw() -> void :
	if not visible: return
	# Live trace while drawing a slide: a gold line with a bright tip.
	for id in draw_touches:
		var trace: Array = []
		for sample in draw_touches[id].samples:
			var point = screen_point(sample.x, sample.y)
			if point != null: trace.append(point)
		if trace.size() >= 2:
			draw_polyline(PackedVector2Array(trace), Color(0, 0, 0, 0.6), 12, true)
			draw_polyline(PackedVector2Array(trace), Color("f9d568"), 6, true)
		if not trace.is_empty(): draw_circle(trace[-1], 10, Color("fff4c8"))
	for handle in handles():
		var point: Vector2 = handle.position
		var color = Color("7ee9ff") if handle.kind == "start" else (Color("ffafcb") if handle.kind == "end" else Color("fff0ae"))
		if handle.kind == "point" and handle.index == selected_point_index: color = Color("ffffff")
		var radius = 14.0 if handle.kind == "point" else 19.0
		draw_circle(point, radius + 4, Color(0, 0, 0, 0.75))
		draw_arc(point, radius, 0, TAU, 32, color, 3, true)
		draw_circle(point, 4, color)
		if handle.kind != "point": draw_string(ThemeDB.fallback_font, point + Vector2(-25, - radius - 10), handle.kind.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
func handle_event(id: int, p: Vector2, began: bool, ended: bool, canceled: bool) -> bool:
	if draw_touches.has(id):
		if canceled: draw_touches.erase(id);game.arrange_touches.erase(id)
		elif ended:
			finish_draw(draw_touches[id].samples)
			draw_touches.erase(id);game.arrange_touches.erase(id)
		else:
			var samples: Array = draw_touches[id].samples
			var sample = Vector2(game.stage_time_at(p), game.arrange_lane_at(p))
			if samples.is_empty() or samples[-1].distance_to(sample) > 0.02: samples.append(sample)
		queue_redraw();return true
	if began and edit_mode == "draw" and not game.dots_mode and draw_touches.is_empty() and drags.is_empty():
		var draw_note = selected_note()
		if not draw_note.is_empty() and game.recorder.writable(draw_note) and not game.outside_highway(p):
			draw_touches[id] = {"samples": [Vector2(game.stage_time_at(p), game.arrange_lane_at(p))]}
			game.arrange_touches[id] = {"kind": "handle"}
			queue_redraw();return true
	if blocked_touches.has(id):
		if ended or canceled:blocked_touches.erase(id)
		return true
	if drags.has(id):
		var drag: Dictionary = drags[id]
		if canceled:
			if drag.changed:
				replace_note(drag.note,edit(drag.note,drag.kind,-float(drag.applied_dt),-float(drag.applied_dl),int(drag.index),game.length()))
			if drag.changed and drag.document and drags.size()==1:
				game.document.undo_stack.resize(drag.undo_size);game.document.redo_stack = drag.redo
				game.document.dirty = drag.was_dirty
		elif not ended:
			var dt = game.stage_time_at(p) - float(drag.pointer_time)
			var dl = game.arrange_lane_at(p) - float(drag.pointer_lane)
			var before_time=handle_time(drag.note,drag.kind,int(drag.index))
			var before_lane=handle_lane(drag.note,drag.kind,int(drag.index))
			var edited = edit(drag.note, drag.kind, dt-float(drag.applied_dt), dl-float(drag.applied_dl), int(drag.index), game.length())
			if drag.kind == "point": snap_point(edited, int(drag.index))
			if edited != drag.note:
				if not drag.changed and drag.document: game.document.checkpoint()
				if drag.note.kind == "slide": SynkChart.sync_connectors(edited)
				drag.changed = true;replace_note(drag.note, edited);game.refresh_arrange_controls()
				drag.applied_dt=float(drag.applied_dt)+handle_time(drag.note,drag.kind,int(drag.index))-before_time
				drag.applied_dl=float(drag.applied_dl)+handle_lane(drag.note,drag.kind,int(drag.index))-before_lane
			game.arrange_preview.request(float(drag.note.time) + (float(drag.note.duration) if drag.kind == "end" else (float(drag.note.path[drag.index].offset) if drag.kind == "point" else 0.0)))
		if ended or canceled:
			drags.erase(id);game.arrange_touches.erase(id)
			if not canceled and drags.is_empty(): game.commit_take_history()
		queue_redraw();return true
	var note = selected_note()
	if not began or edit_mode == "move" or game.dots_mode or note.is_empty() or not game.recorder.writable(note): return false
	var local = get_global_transform_with_canvas().affine_inverse() * (p * game.size)
	var best: Dictionary = {}; var distance = 29.0
	for handle in handles():
		var gap = local.distance_to(handle.position)
		if gap < distance: distance = gap;best = handle
	if best.is_empty(): return false
	for active in drags.values():
		if is_same(active.note,note) and active.kind==best.kind and active.index==best.index:
			blocked_touches[id]=true;return true
	selected_note_ref = note
	selected_point_index = int(best.index) if best.kind == "point" else -1
	var in_document = bool(game.arrange_selection.get("document", false))
	drags[id] = {"kind": best.kind, "index": best.index, "note": note, "pointer_time": game.stage_time_at(p), "pointer_lane": game.arrange_lane_at(p), "applied_dt":0.0,"applied_dl":0.0,"changed": false, "document": in_document, "undo_size": game.document.undo_stack.size(), "redo": game.document.redo_stack.duplicate(true) if in_document else [], "was_dirty": game.document.dirty}
	game.arrange_touches[id] = {"kind": "handle"};game.arrange_preview.request(best.at)
	return true
static func replace_note(note: Dictionary, value: Dictionary) -> void :
	note.clear();note.merge(value.duplicate(true))
static func handle_time(note:Dictionary,kind:String,index:int)->float:
	if kind=="start":return float(note.time)
	if kind=="end":return float(note.time)+float(note.duration)
	return float(note.time)+float(note.path[index].offset)
static func handle_lane(note:Dictionary,kind:String,index:int)->float:
	if kind=="start":return float(note.lane)
	if kind=="end":return float(note.end_lane)
	return float(note.path[index].lane)
static func edit(original: Dictionary, kind: String, dt: float, dl: float, index: int, song_end: float) -> Dictionary:
	var result = original.duplicate(true)
	if kind == "point":
		if index <= 0 or index >= result.path.size() - 1: return result
		var low = float(result.path[index - 1].offset) + 0.005; var high = float(result.path[index + 1].offset) - 0.005
		if high <= low: return result
		result.path[index].offset = clampf(float(original.path[index].offset) + dt, low, high)
		result.path[index].lane = snappedf(clampf(float(original.path[index].lane) + dl, 0, SynkChart.MAX_LANE), 0.05)
		if original.has("checkpoints"):
			var previous=float(original.path[index].offset)
			for i in result.checkpoints.size():
				if absf(float(result.checkpoints[i])-previous)<=.01:
					var check_low=.02 if i==0 else float(result.checkpoints[i-1])+.005
					var check_high=float(result.duration)-.02 if i==result.checkpoints.size()-1 else float(result.checkpoints[i+1])-.005
					result.path[index].offset=clampf(float(result.path[index].offset),maxf(low,check_low),minf(high,check_high))
					result.checkpoints[i]=float(result.path[index].offset)
					break
		return result
	var start = float(original.time); var finish = start + float(original.duration)
	var start_limit=finish-.04
	var end_limit=start+.04
	if original.kind=="slide" and original.path.size()>2:
		start_limit=minf(start_limit,start+float(original.path[1].offset)-.005)
		end_limit=maxf(end_limit,start+float(original.path[-2].offset)+.005)
	if original.has("checkpoints") and not original.checkpoints.is_empty():
		start_limit=minf(start_limit,start+float(original.checkpoints[0])-.02)
		end_limit=maxf(end_limit,start+float(original.checkpoints[-1])+.02)
	var new_start = clampf(start + dt, 0, start_limit) if kind == "start" else start
	var new_end = clampf(finish + dt, end_limit, song_end) if kind == "end" else finish
	result.time = new_start;result.duration = new_end - new_start
	if original.kind == "slide":
		if result.path.size()<2:result.path=[{"offset":0.0,"lane":float(result.lane)},{"offset":float(result.duration),"lane":float(result.end_lane)}]
		if kind=="start":
			result.lane=clampi(roundi(float(original.lane)+dl),0,SynkChart.MAX_LANE)
			result.path[0].lane=float(result.lane)
			for i in range(1,result.path.size()):result.path[i].offset=float(original.path[i].offset)+start-new_start
		else:
			result.end_lane=clampi(roundi(float(original.end_lane)+dl),0,SynkChart.MAX_LANE)
			result.path[-1].offset=float(result.duration)
			result.path[-1].lane=float(result.end_lane)
	else: result.end_lane = result.lane;result.path = []
	if original.has("checkpoints"):
		if kind=="start":
			for i in result.checkpoints.size():result.checkpoints[i]=float(original.checkpoints[i])+start-new_start
	return result

func reshape(operation: String) -> void :
	var note = selected_note()
	if note.is_empty() or note.kind != "slide" or not drags.is_empty() or not game.recorder.writable(note): return
	var path: Array
	if operation == "straighten":
		path = [{"offset": 0.0, "lane": SynkChart.lane_at(note, float(note.time))}, {"offset": float(note.duration), "lane": SynkChart.lane_at(note, float(note.time) + float(note.duration))}]
	else: path = smooth_path(note)
	if path == note.path: return
	if game.arrange_selection.get("document", false): game.document.checkpoint()
	note.path = path
	SynkChart.sync_connectors(note)
	selected_point_index = -1
	game.commit_take_history();game.refresh_arrange_controls();queue_redraw()

func delete_selected_point() -> void:
	var note = selected_note()
	if note.is_empty() or note.kind != "slide" or not game.recorder.writable(note): return
	if selected_point_index <= 0 or selected_point_index >= note.path.size() - 1: return
	if game.arrange_selection.get("document", false): game.document.checkpoint()
	remove_point(note, selected_point_index)
	selected_point_index = -1
	game.commit_take_history();game.refresh_arrange_controls();queue_redraw()

static func remove_point(note: Dictionary, index: int) -> void:
	if index <= 0 or index >= note.path.size() - 1: return
	var offset = float(note.path[index].offset)
	note.path.remove_at(index)
	if note.has("checkpoints"):
		var checks: Array = note.checkpoints.filter(func(value): return absf(float(value) - offset) > .01)
		if checks.is_empty(): note.erase("checkpoints")
		else: note.checkpoints = checks


static func smooth_path(note: Dictionary) -> Array:
	var path: Array = note.path.duplicate(true)
	if path.size() <= 2: return path
	var scale = 9.0 / maxf(0.001, float(note.duration))
	var points: Array = []
	for point in path: points.append(Vector2(float(point.offset) * scale, float(point.lane)))
	var keep = {0: true, path.size() - 1: true}
	for i in range(1, path.size() - 1):
		for checkpoint in note.get("checkpoints", []):
			if absf(float(path[i].offset) - float(checkpoint)) <= .01: keep[i] = true
	var ranges: Array = [Vector2i(0, path.size() - 1)]
	while not ranges.is_empty():
		var span: Vector2i = ranges.pop_back(); var greatest = 0.16; var chosen = -1
		for i in range(span.x + 1, span.y):
			var distance: float = points[i].distance_to(Geometry2D.get_closest_point_to_segment(points[i], points[span.x], points[span.y]))
			if distance > greatest: greatest = distance;chosen = i
		if chosen >= 0:
			keep[chosen] = true;ranges.append(Vector2i(span.x, chosen));ranges.append(Vector2i(chosen, span.y))
	var result: Array = []
	for i in path.size():
		if keep.has(i): result.append(path[i])
	return result

# --- Flexible slide design ------------------------------------------------------------

# Apply the recorder's snap setting to one dragged bend point, inside its neighbours.
func snap_point(note: Dictionary, index: int) -> void:
	if index <= 0 or index >= note.path.size() - 1: return
	var point: Dictionary = note.path[index]
	point.lane = game.snap_slide_lane(float(point.lane))
	var low = float(note.path[index - 1].offset) + 0.005; var high = float(note.path[index + 1].offset) - 0.005
	var snapped = game.snap_slide_time(float(note.time) + float(point.offset)) - float(note.time)
	if snapped >= low and snapped <= high: point.offset = snapped

static func inner_points(note: Dictionary) -> Array:
	var result: Array = []
	if note.kind != "slide": return result
	for i in range(1, note.path.size() - 1): result.append(i)
	return result

static func point_curved(note: Dictionary, index: int) -> bool:
	return bool(note.path[index].get("curve", not bool(note.get("ssrg_path", false))))

func curved(note: Dictionary, inner: Array) -> bool:
	if selected_point_index > 0 and selected_point_index < note.path.size() - 1: return point_curved(note, selected_point_index)
	return inner.all(func(i): return point_curved(note, i))

# Curve or corner: the selected bend point, or every bend when none is selected.
func toggle_curve() -> void:
	var note = selected_note()
	if note.is_empty() or note.kind != "slide" or not game.recorder.writable(note): return
	var inner = inner_points(note)
	if inner.is_empty(): return
	begin_change()
	var targets = [selected_point_index] if selected_point_index > 0 and selected_point_index < note.path.size() - 1 else inner
	var value = not curved(note, inner)
	for i in targets: note.path[i].curve = value
	end_change()

func begin_change() -> void:
	if game.arrange_selection.get("document", false): game.document.checkpoint()
func end_change() -> void:
	game.commit_take_history();game.refresh_arrange_controls();queue_redraw()

# Holds become slides when given a shape.
static func ensure_slide(note: Dictionary) -> void:
	if note.kind == "hold": note.kind = "slide";note.end_lane = note.lane
	note.ssrg_path = true
	if note.get("path", []).size() < 2:
		note.path = [{"offset": 0.0, "lane": float(note.lane)}, {"offset": float(note.duration), "lane": float(note.end_lane)}]

# Replace the path, keeping lane/end_lane in step with its first and last points.
static func write_path(note: Dictionary, path: Array) -> void:
	for point in path: point.lane = clampf(float(point.lane), 0, SynkChart.MAX_LANE)
	path[0].offset = 0.0;path[-1].offset = float(note.duration)
	note.lane = clampi(roundi(float(path[0].lane)), 0, SynkChart.MAX_LANE);path[0].lane = float(note.lane)
	note.end_lane = clampi(roundi(float(path[-1].lane)), 0, SynkChart.MAX_LANE);path[-1].lane = float(note.end_lane)
	note.path = path
	SynkChart.sync_connectors(note)

# One-tap shapes built from the slide's start lane and length, heading toward the centre.
static func preset_path(note: Dictionary, preset: String) -> Array:
	var d = float(note.duration); var base = float(note.lane)
	var toward = 1.0 if base <= SynkChart.MAX_LANE * 0.5 else -1.0
	var amp = 3.0 * toward
	var result: Array = []
	match preset:
		"zigzag":
			for k in 7: result.append({"offset": d * k / 6.0, "lane": base + (amp if k % 2 == 1 else 0.0), "curve": false})
		"wave":
			for k in 9: result.append({"offset": d * k / 8.0, "lane": base + amp * 0.5 * (1.0 - cos(TAU * k / 4.0)), "curve": true})
		"s_curve":
			result = [{"offset": 0.0, "lane": base}, {"offset": d * 0.2, "lane": base, "curve": true}, {"offset": d * 0.8, "lane": base + amp, "curve": true}, {"offset": d, "lane": base + amp}]
		"sweep":
			var target = float(SynkChart.MAX_LANE) - base
			result = [{"offset": 0.0, "lane": base}, {"offset": d * 0.12, "lane": base, "curve": true}, {"offset": d * 0.88, "lane": target, "curve": true}, {"offset": d, "lane": target}]
		"mirror":
			for point in note.path: result.append(point.duplicate());result[-1].lane = float(SynkChart.MAX_LANE) - float(point.lane)
		"flip":
			for i in range(note.path.size() - 1, -1, -1):
				var point = note.path[i].duplicate();point.offset = d - float(point.offset);result.append(point)
	return result

func apply_preset(preset: String) -> void:
	var note = selected_note()
	if note.is_empty() or note.kind not in ["hold", "slide"] or not game.recorder.writable(note): return
	if preset == "flip" and note.kind != "slide": return
	begin_change()
	ensure_slide(note)
	var path = preset_path(note, preset)
	if preset == "flip" and note.has("checkpoints"):
		var flipped: Array = []
		for value in note.checkpoints: flipped.push_front(float(note.duration) - float(value))
		note.checkpoints = flipped
	elif preset != "mirror": note.erase("checkpoints")
	write_path(note, path)
	selected_point_index = -1
	end_change()

# Turn a finger trace into the slide: its span sets start and length, and a simplified
# set of smooth bends follows the trace.
func finish_draw(samples: Array) -> void:
	var note = selected_note()
	if note.is_empty() or not game.recorder.writable(note): return
	var ordered = samples.duplicate();ordered.sort_custom( func(a, b): return a.x < b.x)
	var clean: Array = []
	for sample in ordered:
		if sample.x < 0: continue
		if clean.is_empty() or sample.x - clean[-1].x >= 0.01: clean.append(sample)
	if clean.size() < 2 or clean[-1].x - clean[0].x < 0.1: return
	begin_change()
	var start = game.snap_slide_time(clean[0].x)
	var finish = maxf(start + 0.1, game.snap_slide_time(clean[-1].x))
	if note.kind == "hold": note.kind = "slide"
	note.ssrg_path = true;note.erase("checkpoints")
	note.time = start;note.duration = finish - start
	var raw: Array = []
	for sample in clean:
		raw.append({"offset": clampf(sample.x - start, 0, note.duration), "lane": clampf(sample.y, 0, SynkChart.MAX_LANE), "curve": true})
	raw[0].offset = 0.0;raw[-1].offset = note.duration
	note.path = raw
	var path = smooth_path(note)
	for i in range(1, path.size() - 1): path[i].lane = game.snap_slide_lane(float(path[i].lane))
	write_path(note, path)
	selected_point_index = -1
	end_change()
