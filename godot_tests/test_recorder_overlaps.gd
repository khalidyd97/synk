extends SceneTree
# Recorder overlap tools: find, step through, fix one, and auto-space every overlap.
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ", message)
	else: failures += 1;push_error(message);print("FAIL: ", message)
func _initialize() -> void: run.call_deferred()
func clash_notes() -> Array:
	var hold = SynkChart.note(3.0, 5, "hold");hold.duration = 1.0
	return [SynkChart.note(2.0, 4), SynkChart.note(2.0, 5), SynkChart.note(2.0, 6), hold, SynkChart.note(3.5, 5), SynkChart.note(5.0, 1), SynkChart.note(5.0, 9)]
func lanes_apart(notes: Array, gap: float) -> bool:
	for i in notes.size():
		for j in range(i + 1, notes.size()):
			if SynkNoteSpacing.conflict(notes[i], notes[j], gap): return false
	return true
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game);await process_frame
	game.set_process(false)
	game.mode = "record";game.arranging = true
	game.document.notes = []
	game.capture.notes = clash_notes()
	var tools = game.overlap_tools
	tools._process(0);tools.refresh()
	check(tools.visible and tools.bar.visible, "Overlap bar shows in Correct mode")
	check(tools.groups.size() == 2, "Finds the three-note chord and the tap inside the hold (well-spaced notes are fine)")
	check(tools.count_label.text == "2 overlaps", "Bar counts the overlaps")
	tools.step(1)
	check(tools.current == 0 and is_equal_approx(game.song_time, 2.35) and not game.arrange_selection.is_empty(), "Next jumps to the first overlap and selects a note")
	tools.step(1)
	check(tools.current == 1 and is_equal_approx(game.song_time, 3.85), "Next moves to the following overlap")
	tools.step(1)
	check(tools.current == 0, "Next wraps around to the first overlap")
	tools.fix_current("spread")
	var chord = game.capture.notes.filter(func(n): return is_equal_approx(float(n.time), 2.0))
	check(chord.size() == 3 and lanes_apart(chord, tools.gap()), "Spread moves a chord's notes apart")
	# Stagger and keep one on fresh copies.
	game.capture.notes = clash_notes();tools.current = -1;tools.step(1)
	tools.fix_current("stagger")
	var times = game.capture.notes.slice(0, 3).map(func(n): return float(n.time));times.sort()
	var sixteenth = 60.0 / game.chart_bpm() / 4.0
	check(is_equal_approx(times[1] - times[0], sixteenth) and is_equal_approx(times[2] - times[1], sixteenth), "Stagger turns a chord into a sixteenth roll")
	game.capture.notes = clash_notes();tools.current = -1;tools.step(1)
	var before = game.capture.notes.size()
	tools.fix_current("keep")
	check(game.capture.notes.size() == before - 2, "Keep one deletes the other notes in the overlap")
	# One tap auto-spaces everything.
	game.capture.notes = clash_notes();tools.current = -1
	tools.auto_space_all()
	check(tools.find_groups().is_empty(), "Auto-space all leaves no overlaps")
	check(lanes_apart(game.capture.notes, tools.gap()), "Every note has room beside its neighbours")
	check(game.capture.notes.size() == 7 and game.capture.notes.all(func(n): return int(n.lane) >= 0 and int(n.lane) <= SynkChart.MAX_LANE), "Auto-space keeps every note on the highway")
	# Gap setting changes what counts as an overlap.
	tools.choose_gap(0.0);var tight = tools.gap()
	tools.choose_gap(5.0);var wide = tools.gap()
	check(wide > tight and is_equal_approx(wide, 5.0), "Gap setting widens the room notes need")
	# Auto-space opens the picker; the chosen gap is what every overlap gets.
	game.capture.notes = clash_notes();tools.current = -1;tools.picker.visible = false
	tools.press("auto")
	check(tools.picker.visible, "Auto-space opens the gap picker first")
	tools.choose_gap(0.0);var close_count = tools.groups.size()
	tools.choose_gap(4.0)
	check(tools.groups.size() >= close_count and tools.picker_count.text.contains("at this gap"), "Choosing a gap previews the overlaps at that gap")
	tools.buttons.apply.pressed.emit()
	check(not tools.picker.visible and lanes_apart(game.capture.notes, 4.0), "Space all keeps the chosen 4-lane gap between notes")
	check(float(game.prefs.get_value("editor", "overlap_gap_lanes")) == 4.0, "The chosen gap is remembered")
	tools.choose_gap(2.0)
	# Locked note types are never moved.
	game.capture.notes = clash_notes()
	game.recorder.locked = ["tap"]
	tools.auto_space_all()
	check(game.capture.notes.slice(0, 3).map(func(n): return int(n.lane)) == [4, 5, 6], "Locked note types stay where they are")
	game.recorder.locked = []
	print("RESULT failures=", failures)
	quit(1 if failures > 0 else 0)
