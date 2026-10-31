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
	game.mode="menu";game.ui.show();game.ssrg_playables.show()
	if game.lobby.browser:game.lobby.browser.hide()
	var music=game.menu_music;music.volume=.6;music.level=1.0
	var preview=game.ssrg_playables
	var stream=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=8000
	var samples=PackedByteArray();samples.resize(32000);stream.data=samples
	preview.preview_player.stream=stream
	music._process(.2)
	check(is_equal_approx(db_to_linear(music.volume_db),.6),"BGM keeps selected volume while no preview is playing")
	preview.play_preview();music._process(.2)
	check(absf(db_to_linear(music.volume_db)-.05)<.001,"Playing SSRG preview lowers BGM to 5 percent")
	preview.stop_preview();music._process(2)
	check(absf(db_to_linear(music.volume_db)-.6)<.001,"Stopping preview restores the selected BGM volume")
	music.volume=.03;preview.play_preview();music._process(.2)
	check(db_to_linear(music.volume_db)<=.0301,"Preview ducking never raises a quieter user preference")
	music.volume=0.0;music._process(2)
	check(music.stream_paused,"User mute remains silent during previews")
	music.volume=.6;game.mode="play";music._process(2)
	check(music.stream_paused,"Menu BGM remains off during gameplay")
	preview.stop_preview();game.queue_free();await process_frame
	print("SSRG preview BGM ducking failures: ",failures);quit(failures)
