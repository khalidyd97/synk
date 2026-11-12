extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); game.recorder_skd_view=true
	await process_frame
	game.set_process(false)
	game.mode = "record"
	var original_speed = game.recorder_note_speed
	var music_speed = game.audio.pitch_scale
	var play_speed = game.note_speed
	game.recorder_note_speed = 4.9
	game.cycle_recorder_note_speed()
	check(is_equal_approx(game.recorder_note_speed, 5.0) and game.recorder_note_speed_button.text.contains("5.0×"), "Recorder speed reaches 5.0 in 0.1 steps")
	game.cycle_recorder_note_speed()
	check(is_equal_approx(game.recorder_note_speed, .1), "Recorder speed wraps to 0.1")
	check(is_equal_approx(game.note_travel_seconds(), 35.0), "Lowest recorder speed updates note travel (SKD 3.5 s base)")
	check(game.audio.pitch_scale == music_speed and game.note_speed == play_speed, "Recorder note speed does not change song or play speed")
	check(is_equal_approx(float(game.prefs.get_value("editor", "note_speed", 0)), .1), "Recorder note speed persists")
	# Steppers: one step either way, stopping at the ends instead of wrapping.
	game.note_speed_steps[0].pressed.emit()
	check(is_equal_approx(game.recorder_note_speed, .1) and game.note_speed_steps[0].disabled, "Minus stops at the slowest note speed")
	game.note_speed_steps[1].pressed.emit(); game.note_speed_steps[1].pressed.emit()
	check(is_equal_approx(game.recorder_note_speed, .3) and game.recorder_note_speed_button.text.contains("0.3") and not game.note_speed_steps[0].disabled, "Plus raises note speed by 0.1 a tap")
	var music_before = game.record_speed
	game.record_speed = 1.0; game.record_speed_steps[0].pressed.emit()
	check(is_equal_approx(game.record_speed, .75), "Minus lowers the music speed one step")
	for i in 8: game.record_speed_steps[1].pressed.emit()
	check(is_equal_approx(game.record_speed, 1.5) and game.record_speed_steps[1].disabled, "Plus stops at the fastest music speed")
	game.record_speed = music_before; game.apply_record_speed()
	game.recorder_note_speed = original_speed
	game.prefs.set_value("editor", "note_speed", original_speed)
	game.prefs.save("user://preferences.cfg")
	game.queue_free()
	await process_frame
	print("Recorder note speed failures: ", failures)
	quit(failures)
