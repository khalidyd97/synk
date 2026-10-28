extends SceneTree
var failures=0
var game
var point:Vector2

func check(ok:bool,label:String) -> void:
	if not ok:failures+=1;push_error(label)

func freeze(node:Node) -> void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)

func fixture(checkpoints:Array=[],kind:String="hold") -> Dictionary:
	game.pointers.clear();game.ssrg_touch_router.reset();game.field.world.clear_hit_effects()
	game.song_time=1.0;game.live_cursor=0;game.judged=0;game.earned=0;game.combo=0
	game.judgment_counts={"PERFECT":0,"GREAT":0,"GOOD":0,"MISS":0}
	game.pending_end_hits.clear();game.judgement_total_size=-1
	var note=SynkChart.note(1.0,4,kind)
	note.lane=4.5;note.end_lane=4.5;note.duration=2.0;note.checkpoints=checkpoints
	if kind=="slide":note.path=[{"offset":0.0,"lane":4.5},{"offset":2.0,"lane":4.5}];note.ssrg_path=true
	var entry={"note":note,"key":"sustain_test","started":false,"done":false,"pointer":-999,"error":0.0}
	game.live=[entry]
	game.pointer_event(1,point,true,false,false)
	game.update_game() # Flush the source-style per-frame touch batch.
	check(entry.started and not entry.done,"Fixture head starts")
	return entry

func _initialize() -> void:run.call_deferred()

func run() -> void:
	root.size=Vector2i(1440,640)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	freeze(game);game.ssrg_playable_run=true;game.ssrg_lane_count=13
	game.set_mode("play");game.countdown=0;game.resume_countdown=0;game.resume_grace=0;game.auto_play=false
	game.field.sync_projection_style();game.field.world.apply_camera();game.field.world.update_ssrg_warp()
	point=game.field.world.camera.unproject_position(Vector3(0,.035,0))/Vector2(game.field.viewport.size)
	var entry=fixture([1.0])
	game.song_time=1.81;game.update_game()
	check(int(entry.get("checks_done",0))==1,"Connector accepts eligible pre-line contact")
	game.song_time=2.0;game.update_game()
	check(game.judged==2 and game.judgment_counts.PERFECT==2,"Line-crossing middle inherits PERFECT head grade")
	check(not entry.done,"Early middle does not retire later end")
	entry=fixture([1.0],"slide")
	game.song_time=1.3;game.pointer_event(1,point,false,true,false)
	game.update_game() # Flush the source-style per-frame touch batch.
	check(not entry.done and entry.pointer==-999 and game.judgment_counts.MISS==0,"Early release detaches without whole-chain miss")
	check(not bool(entry.get("ssrg_contact",true)),"Detached sustain visual contact stops")
	game.song_time=2.1;game.pointer_event(2,point,true,false,false);game.update_game()
	game.update_game() # Flush the source-style per-frame touch batch.
	check(not entry.done and int(entry.get("checks_done",0))==1,"Another finger regrabs before next checkpoint deadline")
	check(game.judgment_counts.PERFECT==2 and game.judgment_counts.GOOD==0,"Generic lift/regrab preserves middle inheritance")
	entry=fixture([1.0])
	game.song_time=1.3;game.pointer_event(1,point,false,true,false)
	game.update_game() # Flush the source-style per-frame touch batch.
	game.song_time=2.201;game.update_game()
	check(entry.done and game.judgment_counts.MISS==2,"Expired checkpoint misses both remaining checkpoint and end")
	var scored=game.judged
	game.pointer_event(3,point,true,false,false);game.update_game()
	game.update_game() # Flush the source-style per-frame touch batch.
	check(game.judged==scored and game.judgment_counts.MISS==2,"Expired chain cannot revive or double count")
	entry=fixture()
	game.song_time=2.78;game.pointer_event(1,point,false,true,false)
	game.update_game() # Flush the source-style per-frame touch batch.
	check(entry.done and game.judgment_counts.PERFECT==2 and game.judgment_counts.GOOD==0,"Accepted terminal release inherits the earned chain grade")
	entry=fixture()
	game.song_time=2.995;game.pointer_event(1,point,false,true,false)
	game.song_time=3.12;game.update_game()
	check(entry.done and game.judgment_counts.PERFECT==2 and game.judgment_counts.GOOD==0,"On-time release is graded at input time instead of forced GOOD")
	entry=fixture()
	game.song_time=2.77;game.pointer_event(1,point,false,true,false)
	game.update_game() # Flush the source-style per-frame touch batch.
	check(not entry.done and game.judgment_counts.GOOD==0,"Too-early terminal release waits for regrab")
	entry=fixture()
	game.song_time=2.78;game.pointer_event(1,point,false,true,true)
	game.update_game() # Flush the source-style per-frame touch batch.
	check(not entry.done and game.judgment_counts.GOOD==0,"OS cancellation does not award release GOOD")
	game.ssrg_playable_run=false
	entry=fixture()
	game.song_time=1.3;game.pointer_event(1,point,false,true,false)
	game.update_game() # Flush the source-style per-frame touch batch.
	check(entry.done and game.judgment_counts.MISS==1,"Normal SYNK retains immediate early-release miss")
	print("SSRG sustain actual-main integration: %d failures"%failures)
	game.queue_free();await process_frame
	quit(1 if failures else 0)
