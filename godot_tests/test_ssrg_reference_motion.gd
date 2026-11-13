extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size=Vector2i(1240,552)
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame
	game.note_speed=1; game.recorder_note_speed=1
	game.set_mode("play")
	assert(is_equal_approx(game.note_travel_seconds(),3.5),"Normal play at 1x uses SKD's 3.5 s base time")
	var saved_speed=game.prefs.get_value("ssrg","speed_value",3.0)
	game.prefs.set_value("ssrg","speed_value",3.0)
	game.ssrg_playable_run=true; game.highway_style="ssrg"; game.set_mode("play")
	assert(is_equal_approx(game.note_travel_seconds(),3.5),"SKD SPEED 3 is the 3.5 s base time")
	# Measured on a real SKD recording at SPEED 1 (2026-11-13): the whole track takes about
	# 10.45 s and progress rises evenly, so SPEED 1 must stay 3.5/(1/3) = 10.5 s.
	game.prefs.set_value("ssrg","speed_value",1.0)
	assert(is_equal_approx(game.note_travel_seconds(),10.5),"SKD SPEED 1 crosses the track in 10.5 s, as recorded")
	game.prefs.set_value("ssrg","speed_value",10.0)
	assert(is_equal_approx(game.note_travel_seconds(),1.05),"SKD SPEED 10 is ten times faster")
	game.prefs.set_value("ssrg","speed_value",3.0)
	var world=game.field.world; world.apply_camera()
	var camera=world.camera
	assert(camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"SSRG uses a direct 2D orthographic stage")
	var top=camera.unproject_position(Vector3(0,.13,-world.SSRG_STAGE_DISTANCE)).y
	var line=camera.unproject_position(Vector3(0,.13,0)).y
	for u in [.5,.75,.9,1.0]:
		var q=pow(u,6.0)
		var z=-(1.0-u)*world.TRACK_LENGTH
		var position=camera.unproject_position(Vector3(world.ssrg_x(9)*q,.13,world.ssrg_warped_z(z)))
		assert(absf((position.y-top)/(line-top)-q)<.0001,"Direct 2D note position follows recovered sixth-power curve")
		var centre=camera.unproject_position(Vector3.ZERO)
		var edge=camera.unproject_position(Vector3(world.SSRG_NOTE_SIZE.x*q,0,0))
		var full=camera.unproject_position(Vector3(world.SSRG_NOTE_SIZE.x,0,0))
		assert(absf((edge.x-centre.x)/(full.x-centre.x)-q)<.0001,"Note size uses q without extra camera perspective")
	assert(is_zero_approx(world.ssrg_warped_z(0)),"Hit timestamp reaches original judgment coordinate")
	game.ssrg_playable_run=false; game.note_speed=2
	assert(is_equal_approx(game.note_travel_seconds(),1.75),"Speed changes duration without changing the curve")
	game.note_speed=1
	for lane in [0.0,4.5,9.0]:
		var point=camera.unproject_position(Vector3(world.ssrg_x(lane),.035,0))/Vector2(game.field.viewport.size)
		var input=game.field.input_position(point)
		assert(absf(SynkCapture.lane(input.x)-lane)<.001,"Orthographic note lane maps back to matching touch lane")
	game.song_time=5; game.audio.stop()
	assert(is_zero_approx(world.note_position(4,5).z),"Hit timestamp still reaches judgment plane")
	game.recorder_skd_view=false; game.set_mode("record")
	assert(is_equal_approx(game.note_travel_seconds(),2.6),"Recorder's other view retains original travel")
	assert(camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"Recorder restores its original camera")
	game.prefs.set_value("ssrg","speed_value",saved_speed)
	game.queue_free(); await process_frame
	print("SSRG reference motion and normal/recorder isolation: PASS")
	quit()

