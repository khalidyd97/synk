extends SceneTree
# Song sync: Eclipse plays with auto play, the delay changes live, taps measure it,
# CANCEL restores the previous headset settings and SAVE keeps the new delay.
var failures=0
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	var SongSync=load("res://scripts/song_sync.gd")
	var notes: Array=SongSync.sync_notes()
	check(notes.size()>150 and is_equal_approx(notes[1].time-notes[0].time,60.0/128),"One sync note per Eclipse beat")
	var saved_mode=game.bluetooth_mode; var saved_latency=game.bluetooth_latency_ms
	game.change_bluetooth_mode(false); game.change_bluetooth_latency(120)
	game.open_lobby_settings(); game.open_song_sync()
	var sync=game.song_sync
	check(sync.active and sync.visible and game.mode=="play" and game.auto_play,"Song sync starts an auto play run")
	check(str(game.song.id)=="eclipse" and game.live.size()==notes.size(),"Sync run plays Eclipse with the beat chart")
	check(game.bluetooth_mode,"Headset mode is on while tuning so the delay applies")
	sync.nudge(10); sync.nudge(-1)
	check(is_equal_approx(game.bluetooth_latency_ms,129),"Delay buttons change the headset delay live")
	# Eight taps heard 40 ms late suggest raising the delay by 40 ms.
	for i in 8: sync.taps.append(.04)
	sync.refresh()
	check(not sync.use_button.disabled,"Steady taps enable the measured delay")
	sync.use_measurement()
	check(is_equal_approx(game.bluetooth_latency_ms,169),"Measured delay adds the tap error")
	sync.finish(false)
	check(not sync.active and game.mode=="menu" and game.menu_settings_open,"CANCEL returns to settings")
	check(is_equal_approx(game.bluetooth_latency_ms,120) and not game.bluetooth_mode,"CANCEL restores the previous headset settings")
	game.open_song_sync(); game.song_sync.nudge(50); game.song_sync.finish(true)
	check(is_equal_approx(game.bluetooth_latency_ms,170) and game.bluetooth_mode,"SAVE keeps the delay and headset mode")
	check(is_equal_approx(float(game.prefs.get_value("audio","bluetooth_latency_ms",0)),170),"Saved delay persists")
	# Leave the player's own headset settings as they were.
	game.change_bluetooth_mode(saved_mode); game.change_bluetooth_latency(saved_latency)
	game.queue_free(); await process_frame
	if failures==0: print("Song sync: PASS")
	quit(failures)
