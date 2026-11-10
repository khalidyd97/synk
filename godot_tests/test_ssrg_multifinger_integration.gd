extends SceneTree
var game
var failures=0
func check(ok:bool,label:String):
	if not ok:failures+=1;push_error(label)
func freeze(node:Node):
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func point(ui:Vector2) -> Vector2:
	var world=game.field.world
	return world.camera.unproject_position(Vector3(ui.x*world.SSRG_UNIT,.035,-(ui.y+234)*world.SSRG_UNIT))/Vector2(game.field.viewport.size)
func lane_point(lane:float) -> Vector2:
	var world=game.field.world
	return world.camera.unproject_position(Vector3(world.note_x(lane),.035,0))/Vector2(game.field.viewport.size)
func slide(key:String,from:float,to:float) -> Dictionary:
	var note=SynkChart.note(1,0,"slide");note.lane=from;note.end_lane=to;note.duration=2.0
	note.path=[{"offset":0.0,"lane":from},{"offset":1.0,"lane":to},{"offset":2.0,"lane":to}];note.checkpoints=[1.0];note.ssrg_path=true
	return {"note":note,"key":key,"started":false,"done":false,"pointer":-999,"error":0.0}
func fixture():
	game.pointers.clear();game.ssrg_touch_router.reset();game.live_cursor=0;game.judged=0
	game.judgment_counts={"PERFECT":0,"GREAT":0,"GOOD":0,"MISS":0};game.song_time=1.0
	game.field.world.clear_hit_effects();game.pending_end_hits.clear()
func _initialize():run.call_deferred()
func run():
	root.size=Vector2i(1440,640)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame;freeze(game)
	game.ssrg_playable_run=true;game.ssrg_lane_count=13;game.auto_play=false;game.set_mode("play");game.countdown=0
	game.field.sync_projection_style();game.field.world.apply_camera()
	fixture()
	var left=slide("left",3.0,6.0);var right=slide("right",6.0,3.0);game.live=[left,right]
	game.pointer_event(30,lane_point(3.0),true,false,false)
	game.pointer_event(2,lane_point(6.0),true,false,false)
	game.update_game()
	check(left.pointer==30 and right.pointer==2 and game.judged==2,"Two source heads start independently")
	game.song_time=1.9
	game.pointer_event(30,point(Vector2(70,-234)),false,false,false)
	game.pointer_event(2,point(Vector2(-70,-234)),false,false,false)
	game.update_game()
	check(int(left.get("checks_done",0))==1 and int(right.get("checks_done",0))==1,"Crossing slides judge within the original front window")
	check(left.pointer==30 and right.pointer==2,"Crossing slide owner identity is preserved when autoaim eligible")
	check(int(game.pointers[30].ssrg_channel)==6 and int(game.pointers[2].ssrg_channel)==3,"Aim channels follow each crossing slide's next source channel")
	check(game.judgment_counts.MISS==0,"Crossing does not cause artificial misses")
	game.field.world.update_finger_beams()
	check(game.field.world.finger_beams[6].visible and game.field.world.finger_beams[3].visible,"Beams follow routed channels")
	game.song_time=2.0
	game.update_game()
	check(int(left.get("checks_done",0))==1 and int(right.get("checks_done",0))==1,"Crossing slide pucks are not scored twice")
	game.pointer_event(11,point(Vector2(70,-234)),true,false,false)
	game.update_game()
	check(int(game.pointers[11].ssrg_channel)==7,"Unrelated new finger does not inherit another slide's autoaim")
	fixture();left=slide("dense",6.0,6.0);left.note.checkpoints=[1.0,1.05];game.live=[left]
	game.pointer_event(1,point(Vector2(0,-234)),true,false,false)
	game.update_game()
	game.song_time=2.0;game.update_game();game.update_game()
	check(int(left.get("checks_done",0))==1,"Repeated same-frame update consumes one node per channel")
	game.song_time=2.01;game.update_game()
	check(int(left.get("checks_done",0))==2,"Next overlapping connector can judge in its front window on the next frame")
	game.song_time=2.05;game.update_game()
	check(int(left.get("checks_done",0))==2,"Next input frame can score next overlapping node")
	fixture();left=slide("shared_a",6.0,6.0);right=slide("shared_b",6.0,6.0)
	left.started=true;right.started=true;left.sustain_grade="PERFECT";right.sustain_grade="PERFECT";game.live=[left,right]
	game.song_time=2.0;game.pointer_event(9,point(Vector2(0,-234)),true,false,false)
	game.update_game()
	check(int(left.get("checks_done",0))+int(right.get("checks_done",0))==1,"One physical channel does not score two simultaneous chains in one frame")
	game.song_time=2.01;game.update_game()
	check(int(left.get("checks_done",0))==1 and int(right.get("checks_done",0))==1,"Shared channel is not permanently locked to a chain")
	print("SSRG multi-finger actual-main integration: %d failures"%failures)
	game.queue_free();await process_frame;quit(1 if failures else 0)
