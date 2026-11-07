extends SceneTree
# Under SSRG rules a flick needs a swipe in its arrow's direction, not just a press.
var failures=0
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: run.call_deferred()
func screen_point(g,lane: float) -> Vector2:
	var w=g.field.world
	return w.camera.unproject_position(Vector3(w.note_x(lane),.035,0))/Vector2(g.field.viewport.size)
func flick_run(g,direction: int,swipe: Vector2) -> String:
	var f=SynkChart.note(3.0,6,"flick"); f.direction=direction
	g.start_game([f],false); g.countdown=0; g.song_time=3.0
	var p=screen_point(g,6.0)
	g.pointer_event(1,p,true,false,false); g.update_game()
	var after_press=g.live[0].done
	g.song_time=3.03; g.pointer_event(1,p+swipe,false,false,false); g.update_game()
	g.song_time=3.05; g.pointer_event(1,p+swipe,false,true,false); g.update_game()
	if after_press: return "PRESS"
	return "MISS" if g.judgment_counts.MISS>0 else ("HIT" if g.live[0].done else "OPEN")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
	g.set_process(false); g.stage_intro_enabled=false
	check(flick_run(g,1,Vector2(.08,0))=="HIT","A right flick swiped right is hit")
	check(flick_run(g,3,Vector2(-.08,0))=="HIT","A left flick swiped left is hit")
	check(flick_run(g,0,Vector2(0,-.08))=="HIT","An up flick swiped up is hit")
	check(flick_run(g,1,Vector2(-.08,0))=="MISS","A right flick swiped left is missed")
	check(flick_run(g,3,Vector2(0,0))=="MISS","A left flick that is only tapped is missed")
	g.set_mode("menu"); g.queue_free(); await process_frame
	print("SSRG flick direction failures: ",failures)
	quit(failures)
