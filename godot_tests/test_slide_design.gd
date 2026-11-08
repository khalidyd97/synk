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
	check(arranger.visible and arranger.curve_button.visible and arranger.snap_button.visible, "Slide design controls appear for a selected slide")
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
