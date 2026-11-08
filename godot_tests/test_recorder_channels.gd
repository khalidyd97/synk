extends SceneTree
# The recorder pad shows 13 equal lanes (play keeps SSRG spacing) and lights the one under a finger.
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
	check(world.recorder_channels.visible,"Channel pad shown while recording")
	check(not world.lane_markers.visible,"Old lane dashes hidden while recording")
	var span=float(world.recorder_channel_material.get_shader_parameter("span"))
	check(absf(span-1.0)<.001 and absf(world.lane_step()*13.0-world.PAD_HALF_WIDTH*2.0)<.001,"Recorder splits the full pad into 13 equal lanes")
	check(absf(world.lane_x(0.0)+world.PAD_HALF_WIDTH-world.lane_step()*.5)<.001,"Lane 1 sits against the left rail while recording")
	# A finger held on the rightmost channel lights slot 12 only.
	var p=Vector2(.07+(12.5/13.0)*.86-.001,.75)
	game.capture.gestures[99]={"note":SynkChart.note(0,12),"position":p,"lane_shift":0.0}
	await process_frame; await process_frame
	check(world.recorder_lit[12]>.99 and world.recorder_lit[0]<.01,"Held finger lights its channel")
	game.capture.gestures.erase(99)
	for i in 30: await process_frame
	check(world.recorder_lit[12]<.5,"Channel fades after release")
	print("RESULT failures=",failures); quit(1 if failures>0 else 0)
