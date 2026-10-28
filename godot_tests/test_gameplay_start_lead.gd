extends SceneTree
func _initialize():run.call_deferred()
func freeze(node:Node):
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame;freeze(game)
	game.stage_intro_enabled=false;game.note_speed=1;game.ssrg_playable_run=false
	var note=SynkChart.note(0,4)
	game.start_game([note],false,"full")
	game.field.world.prebuilding=false
	assert(is_equal_approx(game.gameplay_start_lead,3.5))
	assert(is_zero_approx(game.live[0].note.time),"Stored note timestamp stays unchanged")
	game._process(3.0)
	assert(game.countdown==0 and not game.audio.playing)
	assert(is_equal_approx(game.song_time,-3.5),"Countdown ends at the entrance, not mid-chart")
	var prior=game.song_time
	game._process(.1)
	assert(is_equal_approx(game.song_time-prior,.1))
	assert(not game.audio.playing and game.judged==0)
	var lead=game.gameplay_start_lead
	game.toggle_pause();game._process(.5)
	assert(is_equal_approx(game.gameplay_start_lead,lead))
	game.toggle_pause();game._process(3.0)
	assert(not game.audio.playing and is_equal_approx(game.gameplay_start_lead,lead),"Resume does not skip the approach")
	game._process(lead)
	assert(game.gameplay_start_lead==0 and game.audio.playing)
	assert(is_zero_approx(game.song_time))
	game.audio.stop();game.start_game([SynkChart.note(10,4)],false,"full")
	assert(is_equal_approx(game.gameplay_start_lead,2.0),"Later first notes retain minimum readiness time")
	game.queue_free();await process_frame
	print("Gameplay entrance, timestamp preservation and pause/resume passed")
	quit()
