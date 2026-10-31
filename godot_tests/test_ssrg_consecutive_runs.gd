extends SceneTree
var failures=0
func check(ok:bool,label:String):
	if not ok:failures+=1;push_error(label)
func freeze(n:Node):
	n.set_process(false);n.set_physics_process(false)
	for c in n.get_children():freeze(c)
func _initialize():run.call_deferred()
func run():
	AudioServer.set_bus_mute(0,true)
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame;freeze(game)
	game.metadata_queue.clear();game.document.load_notes([]);game.stage_intro_enabled=false
	var selected=game.song.duplicate(true);selected.id="ssrg_next_run_probe".sha256_text();selected.title="Run transition fixture";selected.ssrg=[13]
	game.library.songs=[selected];game.ssrg_playables.chart_cache[selected.id]=[{"keys":13,"variant":"lv13","notes":1,"density":1.0,"bpm":120.0}]
	game.ssrg_playables.selected_id=selected.id
	game.set_mode("menu");game.open_ssrg_playables()
	var notes=[SynkChart.note(1,4.5)]
	for run in 2:
		game.song=selected.duplicate(true);game.ssrg_playable_run=true;game.ssrg_lane_count=13
		game.start_game(notes,true);game.field.world.step_prebuild()
		check(game.mode=="play" and game.uses_ssrg_gameplay(),"Consecutive run starts in SSRG gameplay")
		for i in 16:game._process(.5)
		check(game.countdown<=0 and game.audio.playing,"Consecutive run leaves countdown and starts its audio")
		game.begin_finish({"title":selected.title,"score":0,"counts":{},"auto_play":true})
		game.advance_finish(5)
		check(game.mode=="results" and game.ssrg_screens.result_info.get("ssrg",false),"Finished run reaches SSRG results")
		game.ssrg_screens.leave_results()
		check(game.ssrg_playables.visible and not game.lobby.visible,"SSRG results return isolates the source song list from the normal lobby")
		game.song=selected.duplicate(true);game.features.load_variant()
		check(game.song.id==selected.id,"Next chart refresh cannot replace the SSRG song or audio")
	game.ssrg_playable_run=true;game.paused_mode="play";game.set_mode("paused")
	game.ssrg_screens.leave_pause()
	check(game.ssrg_playables.visible and not game.lobby.visible,"Pause-to-song-list uses the same isolated return path")
	game.queue_free();await process_frame
	print("SSRG consecutive run failures: ",failures);quit(failures)
