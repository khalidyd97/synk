extends SceneTree
var game
var failures=0
func check(ok:bool,label:String):
 if not ok:failures+=1;push_error(label)
func freeze(node:Node):
 node.set_process(false)
 for child in node.get_children():freeze(child)
func point(lane:float) -> Vector2:
 var world=game.field.world
 return world.camera.unproject_position(Vector3(world.note_x(lane),.035,0))/Vector2(game.field.viewport.size)
func fixture() -> Dictionary:
 game.pointers.clear();game.ssrg_touch_router.reset();game.live_cursor=0;game.judged=0;game.combo=0;game.song_time=1.0
 game.judgment_counts={"PERFECT":0,"GREAT":0,"GOOD":0,"MISS":0};game.pending_end_hits.clear()
 var note=SynkChart.note(1,6,"slide");note.lane=6.0;note.end_lane=4.5;note.duration=1.0;note.checkpoints=[.8];note.ssrg_path=true
 note.path=[{"offset":0.0,"lane":6.0},{"offset":.8,"lane":6.0},{"offset":1.0,"lane":4.5}]
 var entry={"note":note,"key":"lost_release","started":false,"done":false,"pointer":-999,"error":0.0}
 game.live=[entry];game.pointer_event(1,point(6.0),true,false,false);game.update_game()
 game.song_time=1.7;game.pointer_event(1,point(4.5),false,false,false);game.update_game()
 check(entry.get("checks_done",0)==1 and entry.pointer==-999,"Transient Lost credits its checkpoint and clears the current track owner while retaining physical identity separately")
 return entry
func _initialize():run.call_deferred()
func run():
 root.size=Vector2i(1440,640)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 await process_frame;await process_frame;freeze(game)
 game.ssrg_playable_run=true;game.ssrg_lane_count=13;game.ssrg_touch_sync_ms=0;game.auto_play=false;game.set_mode("play");game.countdown=0;game.resume_countdown=0;game.resume_grace=0
 game.field.sync_projection_style();game.field.world.apply_camera()
 var entry=fixture()
 game.song_time=1.8;game.pointer_event(1,point(4.5),false,true,false);game.update_game()
 check(entry.done and game.judgment_counts.PERFECT==3 and game.judgment_counts.MISS==0,"Valid final lift survives Lost checkpoint in the preceding input batch")
 game.song_time=2.301;game.update_game()
 check(game.judgment_counts.MISS==0,"Valid completed tail cannot expire later")
 entry=fixture();game.song_time=1.75;game.pointer_event(1,point(4.5),false,true,false);game.update_game()
 check(not entry.done,"Retained identity does not widen the 225 ms release window")
 game.song_time=2.301;game.update_game();check(game.judgment_counts.MISS==1,"Too-early lift still misses its terminal deadline")
 entry=fixture();game.song_time=1.8;game.pointer_event(1,point(4.5),false,false,true);game.update_game()
 check(not entry.done,"Canceled touch is never a valid final lift")
 game.song_time=2.301;game.update_game();check(game.judgment_counts.MISS==1,"Cancellation does not auto-complete a tail")
 entry=fixture();game.song_time=1.75;game.pointer_event(1,point(4.5),false,true,false);game.update_game()
 game.song_time=1.76;game.pointer_event(1,point(0.0),true,false,false);game.update_game()
 game.song_time=1.8;game.pointer_event(1,point(4.5),false,true,false);game.update_game()
 check(not entry.done,"Android finger-index reuse cannot turn an unrelated release into the old tail")
 game.song_time=2.301;game.update_game();check(game.judgment_counts.MISS==1,"Unrelated replacement contact cannot rescue an expired chain")
 game.pointers.clear();game.ssrg_touch_router.reset();game.live_cursor=0;game.judged=0;game.combo=0;game.song_time=1.0
 game.judgment_counts={"PERFECT":0,"GREAT":0,"GOOD":0,"MISS":0}
 var hold=SynkChart.note(1,4,"hold");hold.lane=4.5;hold.end_lane=4.5;hold.duration=2.0;hold.checkpoints=[1.8]
 entry={"note":hold,"key":"aimed_release","started":false,"done":false,"pointer":-999,"error":0.0};game.live=[entry]
 game.pointer_event(1,point(4.5),true,false,false);game.update_game()
 game.song_time=2.79;game.pointer_event(1,point(4.95),false,false,false);game.update_game()
 check(entry.get("checks_done",0)==1 and game.pointers[1].ssrg_channel==5,"Owned sustain autoaim accepts a finger beyond the narrow lane collider")
 game.song_time=2.8;game.pointer_event(1,point(4.95),false,true,false);game.update_game()
 check(entry.done and game.judgment_counts.PERFECT==3,"Final lift respects retained same-chain autoaim rather than rejecting its off-center finger")
 game.pointers.clear();game.ssrg_touch_router.reset();game.live_cursor=0;game.judged=0;game.combo=0;game.song_time=1.0
 game.judgment_counts={"PERFECT":0,"GREAT":0,"GOOD":0,"MISS":0}
 var quick=SynkChart.note(1,6,"slide");quick.lane=6.0;quick.end_lane=6.0;quick.duration=.25;quick.checkpoints=[.05,.20];quick.ssrg_path=true
 quick.path=[{"offset":0.0,"lane":6.0},{"offset":.05,"lane":6.75},{"offset":.20,"lane":6.75},{"offset":.25,"lane":6.0}]
 entry={"note":quick,"key":"quick_zigzag","started":false,"done":false,"pointer":-999,"error":0.0};game.live=[entry]
 game.pointer_event(1,point(6.0),true,false,false);game.update_game()
 game.song_time=1.05;game.pointer_event(1,point(6.75),false,false,false);game.update_game()
 check(entry.get("checks_done",0)==1,"Same-channel continuation cannot consume a second judgment in one frame")
 game.song_time=1.15;game.pointer_event(1,point(6.0),false,false,false);game.update_game()
 check(entry.done and game.judged==4 and game.judgment_counts.PERFECT==4,"A rapid channel crossing advances the next eligible linked tail in the same update")
 game.queue_free();await process_frame
 print("SSRG Lost-to-release identity failures: ",failures);quit(failures)
