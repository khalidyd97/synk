extends SceneTree
var failures=0
func check(ok:bool,label:String) -> void:
	if not ok: failures+=1;push_error(label)
func _initialize() -> void:run.call_deferred()
func freeze(node:Node) -> void:
	node.set_process(false)
	for child in node.get_children():freeze(child)
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	freeze(game)
	game.ssrg_playable_run=true;game.set_mode("play");game.countdown=0
	var world=game.field.world;var effect=world.ssrg_theme
	var slide=SynkChart.note(0,0,"slide");slide.duration=2.0;slide.end_lane=9
	slide.ssrg_path=true;slide.path=[{"offset":0.0,"lane":0.0},{"offset":2.0,"lane":9.0}]
	var entry={"done":false,"note":slide}
	game.song_time=.8;game.visual_song_time=1.0;game.visual_clock_ready=true
	game.paused_mode="play";game.set_mode("paused")
	effect.spawn(0,"slide",entry,-999)
	var hit=effect.hits[0]
	effect._process(0)
	var expected=effect.flash_point(world.note_x(SynkChart.lane_at(slide,world.render_time())))
	check(hit.node.position.is_equal_approx(expected),"Slide flash follows displayed note position, including pause")
	game.set_mode("play")
	for fps in [30,60,120]:
		hit.age=0.0
		for frame in fps-1:effect._process(1.0/float(fps))
		check(is_equal_approx(hit.age,fmod(1.0-1.0/float(fps),effect.HOLD_RETRIGGER)),"Sustain pulse keeps equal cadence at %d FPS" % fps)
	game.paused_mode="play";game.set_mode("paused")
	var age=float(hit.age);effect._process(.2)
	check(is_equal_approx(hit.age,age),"Pause freezes sustain pulse")
	game.queue_free();await process_frame
	print("SSRG sustain visual clock failures: ",failures);quit(failures)
