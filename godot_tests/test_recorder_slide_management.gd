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
	var capture=SynkCapture.new()
	var left=Vector2(.07+.86*2.5/13.0,.8);var right=Vector2(.07+.86*8.5/13.0,.8)
	capture.begin(3,2.0,left,"slide");capture.move(3,2.5,right)
	var recorded=capture.end(3,3.0,right)
	check(not recorded.has("checkpoints"),"Recorded slide has no automatic connectors")
	game.field.world.build_note_node("recorder_no_connectors",recorded,true)
	var plain=game.field.world.notes.recorder_no_connectors.node
	check(plain.get_children().filter(func(child):return child.name=="SlideTurnCap").is_empty(),"Recorder trail has no internal connector caps")
	check(game.toggle_checkpoint(recorded,2.5,false),"User can place a connector on the recorded trail")
	game.field.world.build_note_node("recorder_manual_connector",recorded,true)
	var manual=game.field.world.notes.recorder_manual_connector.node
	check(manual.get_children().filter(func(child):return child.name=="SlideTurnCap").size()==1,"Only the manually placed connector receives a cap")
	var split=SynkChart.note(1.0,2,"slide")
	split.duration=2.0;split.end_lane=7
	split.path=[{"offset":0.0,"lane":2.0},{"offset":.6,"lane":4.0},{"offset":1.4,"lane":5.0},{"offset":2.0,"lane":7.0}]
	split.checkpoints=[.6,1.4]
	var edit=preload("res://scripts/recorder_note_arranger.gd")
	var first=edit.edit(split,"start",-.2,1.0,-1,5.0)
	var both=edit.edit(first,"end",.3,-1.0,-1,5.0)
	check(is_equal_approx(both.time,.8) and is_equal_approx(both.time+both.duration,3.3),"Two endpoint touches stretch the same slide independently")
	check(is_equal_approx(both.time+both.path[1].offset,1.6) and is_equal_approx(both.time+both.path[2].offset,2.4) and both.path[1].lane==4.0 and both.path[2].lane==5.0,"Endpoint stretches preserve both connector positions")
	var moved=edit.edit(both,"point",.1,.5,1,5.0)
	check(is_equal_approx(moved.time+float(moved.path[2].offset),2.4) and moved.path[2].lane==5.0,"Dragging one connector preserves the other")
	game.queue_free()
	await process_frame
	print("Recorder slide management failures: ",failures)
	quit(failures)
