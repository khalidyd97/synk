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
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var slide = SynkChart.note(1.0, 2, "slide")
	slide.duration = 1.0;slide.end_lane = 6
	slide.path = [{"offset":0.0,"lane":2.0},{"offset":1.0,"lane":6.0}]
	game.mode = "record";game.arranging = true
	game.arrange_selection = {"note":slide,"document":false}
	await process_frame
	game.note_shape="rectangle"
	game.field.world.build_note_node("recorder_slide_layer",slide,true)
	var visual=game.field.world.notes["recorder_slide_layer"].node
	var head: MeshInstance3D=visual.get_child(0)
	var tail: MeshInstance3D=visual.get_node("SustainEndCap")
	check(head.material_override.shader==load("res://scripts/recorder_note.gdshader") and tail.material_override.shader==head.material_override.shader,"Recorder slide heads and end caps use opaque alpha compositing")
	check(head.material_override.render_priority>0 and tail.material_override.render_priority>0,"Recorder note faces draw above the slide trail")
	var arranger = game.note_arranger
	check(arranger.visible and arranger.delete_point_button.visible, "Slide management controls appear for a selected slide")
	for button in arranger.buttons.values() + arranger.shape_buttons.values() + [arranger.delete_point_button]:
		check(not button.get_global_rect().intersects(game.record_overview.get_global_rect()), "Slide controls leave the top seek bar clear")
		check(not button.get_global_rect().intersects(game.recorder_angle_slider.get_global_rect()), "Slide controls leave the angle slider clear")
	check(game.toggle_checkpoint(slide,1.5,false) and slide.checkpoints == [.5] and slide.path.size() == 3, "Connector adds a path anchor")
	check(game.toggle_checkpoint(slide,1.5,false) and not slide.has("checkpoints") and slide.path.size() == 2, "Removing a straight connector removes its redundant anchor")
	game.queue_free()
	await process_frame
	print("Recorder slide management failures: ",failures)
	quit(failures)
