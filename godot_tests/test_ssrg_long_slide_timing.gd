extends SceneTree
var game
var failures=0
func check(ok:bool,label:String):
	if not ok:failures+=1;push_error(label)
func freeze(node:Node):
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func screen_point(lane:float) -> Vector2:
	var world=game.field.world
	return world.camera.unproject_position(Vector3(world.note_x(lane),.035,0))/Vector2(game.field.viewport.size)
func run_slide(fps:int,holding:bool=false):
	game.pointers.clear();game.ssrg_touch_router.reset();game.live_cursor=0;game.song_time=1.0;game.judged=0
	game.field.world.clear_hit_effects()
	game.judgment_counts={"PERFECT":0,"GREAT":0,"GOOD":0,"MISS":0}
	var note=SynkChart.note(1.0,0,"slide");note.duration=6.0;note.end_lane=9.0;note.ssrg_path=true
	note.path=[{"offset":0.0,"lane":0.0},{"offset":2.0,"lane":9.0},{"offset":4.0,"lane":0.0},{"offset":6.0,"lane":9.0}]
	note.checkpoints=[2.0,4.0]
	if holding:note.kind="hold";note.lane=4.5;note.end_lane=4.5;note.path=[]
	var entry={"key":"continuous","note":note,"started":false,"done":false,"pointer":-999,"error":0.0}
	game.live=[entry]
	game.pointer_event(1,screen_point(note.lane),true,false,false);game.update_game()
	check(entry.started,"Continuous slide starts at %d FPS"%fps)
	for frame in range(1,6*fps+1):
		game.song_time=1.0+float(frame)/fps
		var lane=SynkChart.lane_at(note,game.song_time)
		game.pointer_event(1,screen_point(lane),false,false,false);game.update_game()
		if game.song_time<=2.8:check(int(entry.get("checks_done",0))==0,"First connector waits outside its front window")
		elif game.song_time<=4.8:check(int(entry.get("checks_done",0))<=1,"Second connector waits outside its front window")
		if game.song_time>=3.0 and game.song_time<=4.8:check(int(entry.get("checks_done",0))==1,"First connector judges once valid contact reaches its node")
		if game.song_time<=6.7:check(not entry.done,"Held tail waits outside its end window")
	check(entry.done and game.judged==4,"All connector points and tail judged at %d FPS"%fps)
	check(game.judgment_counts.PERFECT==4 and game.judgment_counts.GOOD==0 and game.judgment_counts.MISS==0,"Following the full long zigzag earns its correct grades at %d FPS"%fps)
func _initialize():run.call_deferred()
func run():
	root.size=Vector2i(1440,640)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame;freeze(game)
	game.ssrg_playable_run=true;game.ssrg_lane_count=13;game.auto_play=false;game.set_mode("play");game.countdown=0;game.resume_grace=0
	game.field.sync_projection_style();game.field.world.apply_camera()
	for fps in [30,60,120]:run_slide(fps);run_slide(fps,true)
	print("SSRG long slide source-window timing: %d failures"%failures)
	game.queue_free();await process_frame;quit(1 if failures else 0)
