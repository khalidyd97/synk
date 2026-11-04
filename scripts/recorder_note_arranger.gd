extends Control

var game: Control
var edit_mode = "shape"
var drags: Dictionary = {}
var buttons: Dictionary = {}
var shape_buttons: Dictionary = {}
var selected_point_index = -1
var selected_note_ref: Dictionary = {}
var delete_point_button: Button
func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 3:
		var key = ["move", "shape", "points"][i]
		var b = preload("res://scripts/recorder_action.gd").new();b.text = ["MOVE", "SHAPE", "CONNECTOR"][i]
		b.caption_size = 16;b.compact = true;b.variant = "tool";add_child(b)
		b.anchor_left = 0.14 + i * 0.13;b.anchor_right = 0.26 + i * 0.13;b.anchor_top = 0.202;b.anchor_bottom = 0.266
		b.pressed.connect( func():
			edit_mode = "move" if key == "move" else "shape"
			game.dots_mode = key == "points" and not game.dots_mode
			game.refresh_arrange_controls())
		buttons[key] = b
	for i in 2:
		var endpoint = "start" if i == 0 else "end"
		var b = preload("res://scripts/recorder_action.gd").new();b.text = "GO " + endpoint.to_upper()
		b.caption_size = 14;b.compact = true;b.variant = "tool";add_child(b)
		b.anchor_left = 0.14 + i * 0.13;b.anchor_right = 0.26 + i * 0.13;b.anchor_top = 0.274;b.anchor_bottom = 0.338
		b.pressed.connect( func(): focus_endpoint(endpoint))
	for i in 2:
		var operation = "smooth" if i == 0 else "straighten"
		var b = preload("res://scripts/recorder_action.gd").new();b.text = "SIMPLIFY" if operation == "smooth" else "STRAIGHTEN"
		b.caption_size = 14;b.compact = true;b.variant = "tool";add_child(b)
		b.anchor_left = 0.40 + i * 0.13;b.anchor_right = 0.52 + i * 0.13;b.anchor_top = 0.274;b.anchor_bottom = 0.338
		b.pressed.connect( func(): reshape(operation));shape_buttons[operation] = b
	delete_point_button = preload("res://scripts/recorder_action.gd").new()
	delete_point_button.text = "DELETE POINT";delete_point_button.caption_size = 14
	delete_point_button.compact = true;delete_point_button.variant = "tool";add_child(delete_point_button)
	delete_point_button.anchor_left = .53;delete_point_button.anchor_right = .66
	delete_point_button.anchor_top = .202;delete_point_button.anchor_bottom = .266
	delete_point_button.pressed.connect(delete_selected_point)
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
		drags.clear();selected_point_index = -1;selected_note_ref = {};return
	if not is_same(selected_note_ref, note):
		selected_point_index = -1
		selected_note_ref = note
	if selected_point_index >= note.path.size() - 1: selected_point_index = -1
	delete_point_button.visible = note.kind == "slide"
	delete_point_button.disabled = selected_point_index <= 0 or not drags.is_empty() or not game.recorder.writable(note)
	for operation in shape_buttons:
		shape_buttons[operation].visible = note.kind == "slide"
		shape_buttons[operation].disabled = not drags.is_empty() or not game.recorder.writable(note) or (note.path.size() <= 2 if operation == "smooth" else note.path.size() == 2)
	for key in buttons: buttons[key].set_selected(game.dots_mode if key == "points" else ( not game.dots_mode and edit_mode == key))
	queue_redraw()
func marker_point(note: Dictionary, at: float) -> Variant:
	var w = game.field.world
	var z = (at - game.song_time) * w.travel_speed()
	if z < - w.TRACK_LENGTH or z > 1.5: return null
	var point = Vector3(w.note_x(SynkChart.lane_at(note, at)), w.trail_height() + 0.07, z)
	if w.camera.is_position_behind(point): return null
	var normalized = w.camera.unproject_position(point) / Vector2(game.field.viewport.size)
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
func _draw() -> void :
	if not visible: return
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
	if drags.has(id):
		var drag: Dictionary = drags[id]
		if canceled:
			replace_note(drag.note, drag.original)
			if drag.changed and drag.document:
				game.document.undo_stack.resize(drag.undo_size);game.document.redo_stack = drag.redo
				game.document.dirty = drag.was_dirty
		elif not ended:
			var dt = game.stage_time_at(p) - float(drag.pointer_time)
			var dl = game.arrange_lane_at(p) - float(drag.pointer_lane)
			var edited = edit(drag.original, drag.kind, dt, dl, int(drag.index), game.length())
			if edited != drag.note:
				if not drag.changed and drag.document: game.document.checkpoint()
				drag.changed = true;replace_note(drag.note, edited);game.refresh_arrange_controls()
			game.arrange_preview.request(float(drag.note.time) + (float(drag.note.duration) if drag.kind == "end" else (float(drag.note.path[drag.index].offset) if drag.kind == "point" else 0.0)))
		if ended or canceled:
			drags.erase(id);game.arrange_touches.erase(id)
			if not canceled: game.commit_take_history()
		queue_redraw();return true
	var note = selected_note()
	if not began or edit_mode == "move" or game.dots_mode or note.is_empty() or not game.recorder.writable(note): return false
	var local = get_global_transform_with_canvas().affine_inverse() * (p * game.size)
	var best: Dictionary = {}; var distance = 29.0
	for handle in handles():
		var gap = local.distance_to(handle.position)
		if gap < distance: distance = gap;best = handle
	if best.is_empty(): return false
	selected_note_ref = note
	selected_point_index = int(best.index) if best.kind == "point" else -1
	var in_document = bool(game.arrange_selection.get("document", false))
	drags[id] = {"kind": best.kind, "index": best.index, "note": note, "original": note.duplicate(true), "pointer_time": game.stage_time_at(p), "pointer_lane": game.arrange_lane_at(p), "changed": false, "document": in_document, "undo_size": game.document.undo_stack.size(), "redo": game.document.redo_stack.duplicate(true) if in_document else [], "was_dirty": game.document.dirty}
	game.arrange_touches[id] = {"kind": "handle"};game.arrange_preview.request(best.at)
	return true
static func replace_note(note: Dictionary, value: Dictionary) -> void :
	note.clear();note.merge(value.duplicate(true))
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
	var new_start = clampf(start + dt, 0, finish - 0.04) if kind == "start" else start
	var new_end = clampf(finish + dt, start + 0.04, song_end) if kind == "end" else finish
	result.time = new_start;result.duration = new_end - new_start
	if original.kind == "slide":
		var first = clampi(roundi(SynkChart.lane_at(original, new_start) + (dl if kind == "start" else 0.0)), 0, SynkChart.MAX_LANE)
		var last = clampi(roundi(SynkChart.lane_at(original, new_end) + (dl if kind == "end" else 0.0)), 0, SynkChart.MAX_LANE)
		result.lane = first;result.end_lane = last;result.path = [{"offset": 0.0, "lane": float(first)}]
		var path: Array = original.path.duplicate(true)
		if path.is_empty(): path = [{"offset": 0.0, "lane": float(original.lane)}, {"offset": float(original.duration), "lane": float(original.end_lane)}]
		for point in path:
			var at = start + float(point.offset)
			if at > new_start + 0.005 and at < new_end - 0.005: result.path.append({"offset": at - new_start, "lane": point.lane})
		result.path.append({"offset": result.duration, "lane": float(last)})
	else: result.end_lane = result.lane;result.path = []
	if original.has("checkpoints"):
		var checks: Array = []
		for value in original.checkpoints:
			var offset = start + float(value) - new_start
			if offset > 0.02 and offset < result.duration - 0.02: checks.append(offset)
		result.checkpoints = checks
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
