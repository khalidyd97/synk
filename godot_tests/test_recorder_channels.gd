extends SceneTree
# The recorder uses SKD finger beams over its lanes; the old SYNK channel pad stays hidden.
var failures=0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; print("FAIL: ",message)
	else: print("PASS: ",message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame
	game.stage_intro_enabled=false
	var world=game.field.world
	check(world.recorder_channels!=null,"Recorder channel pad exists")
	game.set_mode("menu"); await process_frame; await process_frame
	check(not world.recorder_channels.visible,"Channel pad hidden outside the recorder")
	game.record_here(); game.countdown=0
	await process_frame; await process_frame
	# The recorder draws on SKD's recovered surface: no SYNK pad, SKD finger beams instead.
	check(not world.recorder_channels.visible,"SKD recorder surface hides the SYNK channel pad")
	check(not world.lane_markers.is_visible_in_tree(),"Old lane dashes hidden while recording")
	var p=game.field.project(12.0,0.0)/Vector2(game.field.viewport.size)
	game.pointer_event(99,p,true,false,false)
	await process_frame; await process_frame
	check(game.capture.gestures.has(99),"A touch on the rightmost lane starts a gesture")
	check(world.finger_beams[12].visible and not world.finger_beams[0].visible,"Held finger lights the SKD beam over its lane")
	game.pointer_event(99,p,false,true,false)
	for i in 40: await process_frame
	check(not world.finger_beams[12].visible,"Beam fades after release")
	print("RESULT failures=",failures); quit(1 if failures>0 else 0)
