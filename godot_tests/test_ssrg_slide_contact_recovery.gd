extends SceneTree
var game
var failures=0
func check(ok:bool,label:String):
	if not ok:failures+=1;push_error(label)
func freeze(node:Node):
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func point(y:float=-234.0) -> Vector2:
	var world=game.field.world
	return world.camera.unproject_position(Vector3(0,.035,-(y+234)*world.SSRG_UNIT))/Vector2(game.field.viewport.size)
func fixture(flush:bool=true) -> Dictionary:
	game.pointers.clear();game.ssrg_touch_router.reset();game.live_cursor=0;game.song_time=1.0
	game.judged=0;game.judgment_counts={"PERFECT":0,"GREAT":0,"GOOD":0,"MISS":0}
	var note=SynkChart.note(1,6,"slide");note.lane=6.0;note.end_lane=6.0;note.duration=2.0;note.checkpoints=[1.0];note.ssrg_path=true
	note.path=[{"offset":0.0,"lane":6.0},{"offset":2.0,"lane":6.0}]
	var entry={"key":"contact","note":note,"started":false,"done":false,"pointer":-999,"error":0.0}
	game.live=[entry];game.pointer_event(1,point(),true,false,false)
	if flush:game.update_game()
	return entry
func _initialize():run.call_deferred()
func run():
	root.size=Vector2i(1440,640)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame;freeze(game)
	game.ssrg_playable_run=true;game.ssrg_lane_count=13;game.auto_play=false;game.set_mode("play");game.countdown=0;game.resume_grace=0
	game.field.sync_projection_style();game.field.world.apply_camera()
	var entry=fixture()
	game.song_time=1.3;game.pointer_event(1,point(80),false,false,false);game.update_game()
	game.song_time=1.5;game.pointer_event(1,point(),false,false,false);game.update_game()
	game.song_time=2.0;game.update_game()
	check(int(entry.get("checks_done",0))==1 and not entry.done,"Existing slide finger recovers after returning from the upper touch-band gap")
	entry=fixture()
	game.song_time=1.2;game.pointer_event(2,point(),true,false,false);game.update_game()
	game.song_time=1.4;game.pointer_event(1,point(),false,true,false);game.update_game()
	game.song_time=2.0;game.update_game()
	check(int(entry.get("checks_done",0))==1 and entry.pointer==2 and not entry.done,"Lifting one finger does not erase another held finger in the shared lane")
	entry=fixture()
	game.song_time=1.3;game.pointer_event(1,point(80),false,false,false);game.update_game()
	game.song_time=2.201;game.update_game()
	check(entry.done and game.judgment_counts.MISS==2,"Remaining outside the valid contact region still misses at the real deadline")
	entry=fixture();entry.note.duration=.1;entry.note.checkpoints=[];entry.note.end_lane=6.75
	entry.note.path=[{"offset":0.0,"lane":6.0},{"offset":.1,"lane":6.75}]
	var tap=SynkChart.note(1.11,6);tap.lane=6.0
	var next={"key":"following_tap","note":tap,"started":false,"done":false,"pointer":-999,"error":0.0}
	game.live.append(next)
	var world=game.field.world
	var end_point=world.camera.unproject_position(Vector3(world.note_x(6.75),.035,0))/Vector2(game.field.viewport.size)
	game.song_time=1.1;game.pointer_event(1,end_point,false,true,false)
	game.song_time=1.11;game.pointer_event(1,point(),true,false,false)
	game.song_time=1.12;game.update_game()
	check(entry.done and next.done and game.judgment_counts.MISS==0,"Rapid same-finger slide release and following tap preserve both contacts")
	game.song_time=1.5;game.update_game()
	check(game.judgment_counts.MISS==0,"Previous slide does not expire after its released finger ID was reused")
	entry=fixture(false);entry.note.duration=.1;entry.note.checkpoints=[];entry.note.end_lane=6.75
	entry.note.path=[{"offset":0.0,"lane":6.0},{"offset":.1,"lane":6.75}]
	tap=SynkChart.note(1.11,0);tap.lane=6.75
	next={"key":"same_lane_next","note":tap,"started":false,"done":false,"pointer":-999,"error":0.0};game.live.append(next)
	game.song_time=1.1;game.pointer_event(1,end_point,false,true,false)
	game.song_time=1.11;game.pointer_event(1,end_point,true,false,false)
	game.song_time=1.12;game.update_game()
	check(entry.done and next.done and game.judged==3 and game.judgment_counts.MISS==0,"A full short slide and next same-lane press survive one delayed frame")
	game.update_game();check(game.judged==3,"Queued contacts cannot score twice")
	print("SSRG slide contact recovery: %d failures"%failures)
	game.queue_free();await process_frame;quit(1 if failures else 0)
