extends SceneTree
# SYNK mode's stage holds a backdrop helper that is a plain Node. Refreshing the stage used to
# stop with an error on it, so the rest of the refresh (the song photo behind the stage) was
# skipped whenever a SYNK mode song was paused, resumed or left.
var failures=0
func check(ok:bool,label:String) -> void:
	if not ok:failures+=1;push_error(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	game.highway_style="synk";game.stage_intro_enabled=false
	game.start_game([SynkChart.note(4.0,3),SynkChart.note(4.5,9)],true)
	var world=game.field.world
	for i in 30: await process_frame
	check(game.synk_mode(),"The song runs in SYNK mode")
	check(world.ssrg_theme.synk_backdrop!=null,"SYNK mode has its own backdrop")
	game.set_mode("paused")
	check(game.modal.visible and game.pause_layer.visible,"Pausing in SYNK mode shows the pause card")
	game.set_mode("play")
	check(not game.modal.visible and not game.pause_layer.visible,"Resuming in SYNK mode hides the pause card")
	game.set_mode("menu")
	check(game.lobby.visible and not game.modal.visible,"Leaving a SYNK mode song shows the lobby")
	check(not world.ssrg_theme.active and world.cover_material.get_shader_parameter("photo")==false,"Leaving the song refreshes the stage to the end")
	game.highway_style="synk";game.start_game([SynkChart.note(4.0,3)],true)
	for i in 30: await process_frame
	check(world.ssrg_theme.active and world.cover_material.get_shader_parameter("photo")==true,"Starting again refreshes the stage to the end")
	print("SYNK mode pause: ","PASS" if failures==0 else str(failures)+" FAILED");quit(0 if failures==0 else 1)
