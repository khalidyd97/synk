extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.mode = "record"
	check(game.recorder_angle_slider != null, "Recorder screen has an angle slider")
	game.recorder_angle_slider.value=90.0
	var world = game.field.world
	var tap = {"kind":"tap","lane":6,"time":0.0,"duration":0.0}
	var flick = {"kind":"flick","lane":7,"time":0.0,"duration":0.0,"direction":1}
	world.build_note_node("angle_tap",tap,true)
	world.build_note_node("angle_flick",flick,true)
	world.refresh_highway_look()
	check(is_equal_approx(world.highway_angle(), 90.0), "Recorder accepts the flat overhead angle")
	check(is_equal_approx(world.camera.rotation_degrees.x, -90.0), "Flat view points the recorder camera straight down")
	var tap_head = world.notes.angle_tap.node.get_child(0)
	var flick_arrow = world.notes.angle_flick.node.get_child(1)
	check(is_equal_approx(tap_head.rotation.x,-PI*.5),"Recorder note face lies on the highway in the flat view")
	check(is_equal_approx(flick_arrow.rotation.x,-PI*.5),"Recorder flick arrow lies on the highway in the flat view")
	var band: Color=world.judgment_material.get_shader_parameter("base_color")
	check(absf(band.r-band.g)<.03 and absf(band.g-band.b)<.05, "Recorder judgment bar stays gray")
	var bar = game.field.project(6.0, 0.0)
	check(is_finite(bar.x) and is_finite(bar.y), "The judgment bar projects in the flat view")
	var lane = game.field.project(9.0, 0.0) / Vector2(game.field.viewport.size)
	var mapped = game.field.input_position(lane)
	check(absf(SynkCapture.lane(mapped.x) - 9.0) < 0.5, "Flat recorder view keeps input aligned with lanes")
	game.change_highway_angle(35.0)
	check(is_equal_approx(world.camera.rotation_degrees.x, -35.0), "The previous recorder perspective remains available")
	check(is_equal_approx(tap_head.rotation.x,-PI*.5),"Recorder note stays flat on the highway in perspective")
	check(is_equal_approx(flick_arrow.rotation.x,-PI*.5),"Recorder arrow stays flat on the highway in perspective")
	check(is_equal_approx(game.recorder_angle_slider.value,35.0) and game.recorder_angle_label.text=="35°", "Recorder slider follows angle changes")
	game.queue_free()
	await process_frame
	print("Recorder angle failures: ", failures)
	quit(failures)
