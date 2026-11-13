extends SceneTree
var failures=0
func check(ok:bool,label:String):
	if not ok:failures+=1;push_error(label)
func freeze(node:Node):
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func _initialize():run.call_deferred()
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game); game.recorder_skd_view=true
	await process_frame;await process_frame
	game.set_mode("play");game.ssrg_playable_run=true;game.countdown=0;freeze(game)
	for dimensions in [Vector2i(1280,720),Vector2i(2400,1080),Vector2i(2340,1080),Vector2i(2048,1536),Vector2i(1024,768)]:
		root.size=dimensions;game.size=dimensions;game.field.size=dimensions;game.field.resize_viewport()
		var world=game.field.world;world.update_ssrg_warp()
		for index in [0,2]:
			game.note_size=1.25;game.prefs.set_value("ssrg","note_scale_index",index)
			var sizing=game.ssrg_note_scale();world.apply_camera()
			var canvas=world.ssrg_canvas_height()
			if float(dimensions.x)/dimensions.y>=1.75:check(is_equal_approx(canvas,640.0),"Phone reference scale stays unchanged")
			var bottom=world.camera.unproject_position(Vector3(0,.035,86.0*world.SSRG_UNIT))
			check(absf(bottom.y-dimensions.y)<.1,"Highway bottom stays attached after resizing")
			var line=world.camera.unproject_position(Vector3(0,.035,0))/Vector2(dimensions)
			check(line.y>.84 and line.y<.93,"Judgment stays in lower touch area")
			for lanes in [4,7,13]:
				game.ssrg_lane_count=lanes
				for slot in range(lanes):
					var lane=float(slot)*9.0/(lanes-1)
					var center=world.note_x(lane)
					for side in [-1,1]:
						var edge=world.camera.unproject_position(Vector3(center+side*106.0*world.SSRG_UNIT*sizing,.13,0))
						check(edge.x>=0 and edge.x<=dimensions.x,"All outer note sprites fit")
					var normalized=world.camera.unproject_position(Vector3(center,.035,0))/Vector2(dimensions)
					check(game.ssrg_touch_lane(game.field.touch_world_position(normalized),lane),"Resized touch ray still matches original channel")
			var far=game.field.project(4.5,1)/Vector2(dimensions)
			var near=game.field.project(4.5,0)/Vector2(dimensions)
			check(far.y>=0 and far.y<near.y,"HUD projection uses the source approach plane")
			game.align_gameplay_hud()
			check(game.countdown_label.get_global_rect().get_center().y>0 and game.countdown_label.get_global_rect().get_center().y<dimensions.y,"Countdown remains on screen")
	game.set_mode("record");game.field.sync_projection_style();game.field.world.apply_camera()
	check(game.field.world.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"Recorder uses the SKD orthographic camera")
	game.queue_free();await process_frame
	print("SSRG screen fitting failures: ",failures);quit(failures)
