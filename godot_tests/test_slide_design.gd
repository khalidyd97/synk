extends SceneTree
# Flexible slide design in the recorder: curve/corner bends, presets, drawing and snapping.
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ", message)
	else: failures += 1;push_error(message);print("FAIL: ", message)
func _initialize() -> void: run.call_deferred()
func slide_note() -> Dictionary:
	var s = SynkChart.note(1.0, 2, "slide");s.duration = 1.0;s.end_lane = 2;s.ssrg_path = true
	s.path = [{"offset": 0.0, "lane": 2.0}, {"offset": 0.5, "lane": 6.0}, {"offset": 1.0, "lane": 2.0}]
	return s
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game);await process_frame
	game.set_process(false)
	# Path model.
	var s = slide_note()
	check(is_equal_approx(SynkChart.lane_at(s, 1.25), 4.0), "SSRG bends default to sharp corners (straight segments)")
	s.path[1].curve = true
	check(SynkChart.lane_at(s, 1.25) > 4.2, "A curved bend rounds its segments")
	var legacy = slide_note();legacy.erase("ssrg_path")
	var curved_legacy = slide_note();curved_legacy.erase("ssrg_path");curved_legacy.path[1].curve = true
	check(is_equal_approx(SynkChart.lane_at(legacy, 1.3), SynkChart.lane_at(curved_legacy, 1.3)), "Older SYNK slides keep their smooth curve")
	# Editor actions on a selected slide.
	var note = slide_note()
	game.mode = "record";game.arranging = true
	game.arrange_selection = {"note": note, "document": false}
	var arranger = game.note_arranger
	await process_frame;arranger._process(0)
	check(arranger.visible and arranger.snap_button.visible and not arranger.curve_button.visible, "A selected slide shows the tool row, with the rest folded away")
	arranger.expanded = true;arranger._process(0)
	check(arranger.curve_button.visible and arranger.preset_buttons["wave"].visible, "MORE unfolds the shape rows")
	for button in arranger.preset_buttons.values() + [arranger.curve_button, arranger.snap_button]:
		check(not button.get_global_rect().intersects(game.record_overview.get_global_rect()), "Slide design controls leave the seek bar clear")
	arranger.toggle_curve()
	check(note.path[1].get("curve", false), "Curve all rounds every bend")
	arranger.toggle_curve()
	check(not note.path[1].get("curve", true), "Tapping again returns bends to corners")
	arranger.apply_preset("zigzag")
	check(note.path.size() == 7 and float(note.path[1].lane) == 5.0 and float(note.path[2].lane) == 2.0, "Zigzag alternates three lanes toward the centre")
	arranger.apply_preset("mirror")
	check(note.lane == 10 and float(note.path[1].lane) == 7.0, "Mirror reflects the slide across the highway")
	arranger.apply_preset("sweep")
	check(note.end_lane == 2 and note.path.size() == 4, "Sweep crosses the highway")
	var before_end = note.end_lane;var before_start = note.lane
	arranger.apply_preset("flip")
	check(note.lane == before_end and note.end_lane == before_start, "Flip reverses the slide in time")
	var hold = SynkChart.note(3.0, 4, "hold");hold.duration = 0.8
	game.arrange_selection = {"note": hold, "document": false}
	arranger.apply_preset("wave")
	check(hold.kind == "slide" and hold.path.size() == 9 and hold.path[2].get("curve", false), "A hold becomes a curved wave slide")
	# Drawing.
	game.arrange_selection = {"note": note, "document": false}
	var samples: Array = []
	for k in 41: samples.append(Vector2(2.0 + k * 0.02, 3.0 + 4.0 * sin(k / 40.0 * PI)))
	arranger.finish_draw(samples)
	check(is_equal_approx(float(note.time), 2.0) and is_equal_approx(float(note.duration), 0.8), "A trace sets the slide's start and length")
	check(note.path.size() >= 3 and note.path.size() < 20 and note.path[1].get("curve", false), "A trace becomes a few smooth bends")
	check(absf(SynkChart.lane_at(note, 2.4) - 7.0) < 0.6, "The drawn slide follows the trace")
	# Every bend point is a connector.
	var inner_offsets: Array = []
	for i in range(1, note.path.size() - 1): inner_offsets.append(snappedf(float(note.path[i].offset), .001))
	check(note.get("checkpoints", []) == inner_offsets, "Every bend of a drawn slide is a connector")
	arranger.apply_preset("zigzag")
	check(note.get("checkpoints", []).size() == 5, "Every zigzag corner is a connector")
	arranger.reshape("straighten")
	check(not note.has("checkpoints"), "A straight slide has no connectors")
	var capture = SynkCapture.new()
	capture.begin(7, 5.0, Vector2(.07 + .86 * 2.5 / 13.0, .8), "slide")
	capture.move(7, 5.3, Vector2(.07 + .86 * 8.5 / 13.0, .8))
	capture.move(7, 5.6, Vector2(.07 + .86 * 3.5 / 13.0, .8))
	var recorded = capture.end(7, 5.9, Vector2(.07 + .86 * 9.5 / 13.0, .8))
	check(recorded.kind == "slide" and recorded.path.size() >= 3 and recorded.get("checkpoints", []).size() == recorded.path.size() - 2, "Recorded slide turns are connectors")
	check(SynkChart.valid([recorded]), "Recorded slide with connectors stays valid")
	# Connectors can be tapped onto any part of the trail, near or far up the highway.
	var long_slide = SynkChart.note(1.0, 2, "slide");long_slide.duration = 2.0;long_slide.end_lane = 10;long_slide.ssrg_path = true
	long_slide.path = [{"offset": 0.0, "lane": 2.0}, {"offset": 2.0, "lane": 10.0}]
	game.arrange_selection = {"note": long_slide, "document": false}
	game.slide_snap = "free"
	game.song_time = 3.05;game.visual_song_time = 3.05
	await process_frame;await process_frame
	# Near the line, halfway up and almost at the far end of the visible highway.
	var travel = game.note_travel_seconds()
	for offset in [1.9, maxf(.1, 2.05 - travel * .45), maxf(.1, 2.05 - travel * .85)]:
		var at = 1.0 + offset
		var local = arranger.screen_point(at, SynkChart.lane_at(long_slide, at))
		if local == null: check(false, "Trail point at +%.2f s is on screen" % offset);continue
		var p = (arranger.get_global_transform_with_canvas() * local) / game.size
		game.add_point_at(p)
		check(long_slide.get("checkpoints", []).any(func(c): return absf(float(c) - offset) < .06), "A connector can be tapped onto the trail at +%.2f s" % offset)
	var near = arranger.screen_point(2.06, SynkChart.lane_at(long_slide, 2.06))
	var count = long_slide.get("checkpoints", []).size()
	game.add_point_at((arranger.get_global_transform_with_canvas() * near) / game.size)
	check(long_slide.get("checkpoints", []).size() == count + 1, "A connector can sit just beside another one")
	game.arrange_selection = {"note": note, "document": false}
	# Snapping.
	game.slide_snap = "free"
	check(is_equal_approx(game.snap_slide_lane(4.37), 4.35), "Free snapping keeps fine lane steps")
	game.slide_snap = "lanes"
	check(game.snap_slide_lane(4.37) == 4.0, "Lane snapping uses whole lanes")
	game.slide_snap = "beats"
	var step = 60.0 / game.chart_bpm() / 4.0
	check(absf(fposmod(game.snap_slide_time(1.234) - game.chart_offset(), step)) < 0.0001 or absf(fposmod(game.snap_slide_time(1.234) - game.chart_offset(), step) - step) < 0.0001, "Beat snapping lands on sixteenths")
	game.slide_snap = "free"
	print("RESULT failures=", failures)
	quit(1 if failures > 0 else 0)
