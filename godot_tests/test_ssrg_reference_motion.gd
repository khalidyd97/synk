extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size=Vector2i(1240,552)
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame
	game.note_speed=1; game.recorder_note_speed=1
	assert(is_equal_approx(game.note_travel_seconds(),2.6))
	game.set_mode("play")
	assert(game.uses_ssrg_gameplay() and is_equal_approx(game.note_travel_seconds(),1.17),"Normal play shares SSRG motion")
	game.ssrg_playable_run=true; game.highway_style="ssrg"; game.set_mode("play")
	assert(is_equal_approx(game.note_travel_seconds(),1.17))
	var world=game.field.world; world.apply_camera()
	var camera=world.camera
	# Progress along the line from the vanishing point (0) to the judgement line (1).
	var top=camera.unproject_position(Vector3(0,.13,-100000)).y
	var line=camera.unproject_position(Vector3(0,.13,0)).y
	var progress=func(z: float) -> float: return (camera.unproject_position(Vector3(0,.13,world.ssrg_warped_z(z))).y-top)/(line-top)
	assert(is_equal_approx(world.ssrg_warped_z(0),0.0),"Hit timestamp still lands on the line")
	assert(progress.call(-world.TRACK_LENGTH)<.02,"Notes leave the vanishing point")
	# Tracked SSRG notes: p = (K^u - 1)/(K - 1) over the trip, K = 3.3.
	var k=world.SSRG_APPROACH_K
	for u in [.25,.5,.75,.9]:
		var expected=(pow(k,u)-1.0)/(k-1.0)
		assert(absf(progress.call(-(1.0-u)*world.TRACK_LENGTH)-expected)<.01,"Approach follows the SSRG curve")
	var speed_top=progress.call(-.9*world.TRACK_LENGTH)-progress.call(-world.TRACK_LENGTH)
	var speed_line=progress.call(0)-progress.call(-.1*world.TRACK_LENGTH)
	assert(speed_line>2.5*speed_top,"Notes speed up toward the line")
	game.song_time=5; game.audio.stop()
	assert(is_zero_approx(world.note_position(4,5).z),"Hit timestamp still reaches judgment plane")
	game.set_mode("record")
	assert(is_equal_approx(game.note_travel_seconds(),2.6),"Recorder retains original travel")
	game.queue_free(); await process_frame
	print("SSRG reference motion and normal/recorder isolation: PASS")
	quit()

