extends SceneTree
var game
func _initialize():run.call_deferred()
func freeze(node:Node):
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func point(lane:float=4.5) -> Vector2:
	var world=game.field.world
	return world.camera.unproject_position(Vector3(world.note_x(lane),.035,0))/Vector2(game.field.viewport.size)
func fixture(head_at:float) -> Dictionary:
	game.pointers.clear();game.ssrg_touch_router.reset();game.live_cursor=0;game.song_time=head_at;game.judged=0
	game.judgment_counts={"PERFECT":0,"GREAT":0,"GOOD":0,"MISS":0}
	var note=SynkChart.note(1.0,4,"slide");note.lane=4.5;note.end_lane=4.5;note.duration=2.0;note.checkpoints=[1.0];note.ssrg_path=true
	note.path=[{"offset":0.0,"lane":4.5},{"offset":2.0,"lane":4.5}]
	var entry={"key":"audited","note":note,"started":false,"done":false,"pointer":-999,"error":0.0}
	game.live=[entry];game.pointer_event(1,point(),true,false,false);game.update_game();return entry
func run():
	root.size=Vector2i(1440,640)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame;freeze(game)
	game.ssrg_playable_run=true;game.ssrg_lane_count=13;game.auto_play=false;game.set_mode("play");game.countdown=0;game.resume_grace=0
	game.field.sync_projection_style();game.field.world.apply_camera()
	var entry=fixture(.85)
	assert(game.judgement=="GREAT")
	game.song_time=1.81;game.update_game()
	assert(int(entry.get("checks_done",0))==1 and game.judgment_counts.GREAT==2,"Early continuation inherits head grade")
	game.song_time=2.71;game.update_game()
	assert(entry.done and game.judgment_counts.GREAT==3 and game.judgment_counts.GOOD==0,"Tail inherits prior grade despite low raw eligibility rate")
	assert(is_equal_approx(entry.sustain_rate,.5),"Prior chain rate is preserved through tail")
	entry=fixture(1.0)
	game.song_time=1.9;game.pointer_event(1,point(6.0),false,false,false);game.update_game()
	assert(int(entry.get("checks_done",0))==1 and game.judgment_counts.PERFECT==2,"Just-left lane Lost state credits the connector in that update")
	game.song_time=1.91;game.update_game()
	assert(game.ssrg_touch_router.track(6).state==0 and game.judged==2,"Lost credit is transient and cannot duplicate")
	print("Audited SSRG connector rules: early eligibility, rate/grade inheritance through tail and transient Lost passed")
	game.queue_free();await process_frame;quit()
