extends SceneTree
var game
func _initialize():run.call_deferred()
func freeze(node:Node):
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func fixture(at:float=1.0) -> Dictionary:
	game.pointers.clear();game.ssrg_touch_router.reset();game.live_cursor=0;game.song_time=at
	game.judged=0;game.judgment_counts={"PERFECT":0,"GREAT":0,"GOOD":0,"MISS":0}
	var note=SynkChart.note(at,6);note.lane=6.0
	var entry={"note":note,"key":"tap","started":false,"done":false,"pointer":-999,"error":0.0}
	game.live=[entry];return entry
func run():
	root.size=Vector2i(1440,640)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame;freeze(game)
	game.ssrg_playable_run=true;game.ssrg_lane_count=13;game.set_mode("play");game.auto_play=false;game.countdown=0
	game.audio.stop()
	game.field.sync_projection_style();game.field.world.apply_camera()
	var point=game.field.world.camera.unproject_position(Vector3(0,.035,0))/Vector2(game.field.viewport.size)
	var entry=fixture()
	game.pointer_event(1,point,true,false,false)
	game.pointer_event(1,point+Vector2(.001,0),false,false,false)
	game.song_time=1.14;game.update_game()
	assert(entry.done and game.judgement=="PERFECT","A same-frame drag preserves the press and its timestamp")
	assert(is_zero_approx(entry.timing_error),"Timing report reflects the touch, not the later update")
	entry=fixture()
	game.pointer_event(1,point,true,false,false)
	game.song_time=1.02;game.pointer_event(1,point,false,true,false)
	game.song_time=1.16;game.update_game()
	assert(entry.done and game.judgement=="PERFECT" and game.judged==1,"A tap released before a rendered frame still scores once")
	assert(game.pointers.is_empty())
	game.song_time=1.17;game.update_game();assert(game.judged==1,"No ghost repeat after quick release")
	entry=fixture();game.pointer_event(1,point,true,false,false);game.pointer_event(1,point,false,true,true)
	game.update_game();assert(not entry.started,"OS cancellation does not create a pending hit")
	var old=fixture(.85);old.key="older"
	var current=old.duplicate(true);current.note.time=1.0;current.key="current"
	game.live=[old,current];game.song_time=1.0
	game.pointer_event(1,point,true,false,false);game.song_time=1.06;game.update_game()
	assert(current.done and old.done and not old.started and game.judgment_counts.PERFECT==1 and game.judgment_counts.MISS==1,"Dense taps target the closest beat before the older note's automatic-miss pass")
	entry=fixture();game.ssrg_touch_sync_ms=50;game.song_time=1.05
	game.pointer_event(1,point,true,false,false);game.update_game()
	assert(entry.done and game.judgement=="PERFECT" and is_zero_approx(entry.timing_error),"Positive SSRG touch sync compensates a late gameplay-clock sample without widening windows")
	game.ssrg_touch_sync_ms=0
	game.visual_song_time=8.0;game.visual_clock_target=8.0;game.visual_clock_ready=true
	game.smooth_visual_time(7.99,.016)
	assert(game.visual_song_time>=8.0 and game.visual_song_time<=8.015,"SSRG motion smooths mixer jitter without reversing or running far ahead")
	print("SSRG timing: quick taps, same-frame movement, input timestamps, cancellation and smoothed audio-linked motion passed")
	game.queue_free();await process_frame;quit()
