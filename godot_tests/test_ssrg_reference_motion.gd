extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame
	game.note_speed=1; game.recorder_note_speed=1
	assert(is_equal_approx(game.note_travel_seconds(),2.6))
	game.ssrg_playable_run=true; game.highway_style="ssrg"; game.set_mode("play")
	assert(is_equal_approx(game.note_travel_seconds(),2.2))
	var world=game.field.world; world.apply_camera()
	var camera=world.camera
	var far=camera.unproject_position(Vector3(0,.13,-40))
	var middle=camera.unproject_position(Vector3(0,.13,-20))
	var near=camera.unproject_position(Vector3(0,.13,0))
	assert(near.y-middle.y>middle.y-far.y,"Perspective speeds screen motion toward judgment")
	game.song_time=5; game.audio.stop()
	assert(is_zero_approx(world.note_position(4,5).z),"Hit timestamp still reaches judgment plane")
	game.set_mode("record")
	assert(is_equal_approx(game.note_travel_seconds(),2.6),"Recorder retains original travel")
	game.queue_free(); await process_frame
	print("SSRG reference motion and normal/recorder isolation: PASS")
	quit()
