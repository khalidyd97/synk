extends SceneTree

var failures=0

func check(ok:bool,label:String) -> void:
	if not ok:
		failures+=1
		push_error(label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.ssrg_playable_run=true
	game.ssrg_lane_count=13
	var state=game.ssrg_presentation
	game.ssrg_health_disabled=true
	state.reset(100,{},5)
	state.judged("MISS")
	check(state.life==100.0,"Disabled health keeps life full after a miss")
	check(state.state==1,"A miss still drops rave to entry while health is disabled")
	game.set_mode("play")
	game.ssrg_game_over()
	check(not game.ssrg_failed and game.mode=="play","Disabled health blocks life-based failure")
	game.ssrg_health_disabled=false
	state.reset(100,{},0)
	state.judged("MISS")
	check(state.life==70.0,"Normal hard-mode health still loses thirty life")
	game.queue_free()
	await process_frame
	print("SSRG health toggle: ","PASS" if failures==0 else str(failures)+" FAILED")
	quit(failures)
