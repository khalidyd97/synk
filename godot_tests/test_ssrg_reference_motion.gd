extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size=Vector2i(1240,552)
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame
	game.note_speed=1; game.recorder_note_speed=1
	assert(is_equal_approx(game.note_travel_seconds(),2.6))
	game.set_mode("play")
	assert(game.uses_ssrg_gameplay() and is_equal_approx(game.note_travel_seconds(),1.07),"Normal play shares SSRG motion")
	game.ssrg_playable_run=true; game.highway_style="ssrg"; game.set_mode("play")
	assert(is_equal_approx(game.note_travel_seconds(),1.07))
	var world=game.field.world; world.apply_camera()
	var camera=world.camera
	var far=camera.unproject_position(Vector3(0,.13,-40))
	var middle=camera.unproject_position(Vector3(0,.13,-20))
	var near=camera.unproject_position(Vector3(0,.13,0))
	assert(near.y-middle.y>middle.y-far.y,"Perspective speeds screen motion toward judgment")
	# Reference tap advances from y197 to y260 to y403 over two 0.2s steps.
	# Compare normalized screen coordinates so viewport resolution cannot hide drift.
	var viewport_size=camera.get_viewport().get_visible_rect().size
	var start_z=-25.2
	for i in 3:
		var projected=camera.unproject_position(Vector3(0,.36,start_z+float(i)*.2*world.travel_speed()))
		var reference_y=[197.0,260.0,403.0][i]/552.0
		assert(absf(projected.y/viewport_size.y-reference_y)<.006,"Approach matches measured reference frames")
	game.song_time=5; game.audio.stop()
	assert(is_zero_approx(world.note_position(4,5).z),"Hit timestamp still reaches judgment plane")
	game.set_mode("record")
	assert(is_equal_approx(game.note_travel_seconds(),2.6),"Recorder retains original travel")
	game.queue_free(); await process_frame
	print("SSRG reference motion and normal/recorder isolation: PASS")
	quit()

