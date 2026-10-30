extends SceneTree
var failures=0
func check(ok:bool,label:String) -> void:
	if not ok:failures+=1;push_error(label)
func freeze(node:Node) -> void:
	node.set_process(false)
	for child in node.get_children():freeze(child)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	freeze(game);game.stage_intro_enabled=false;game.ssrg_playable_run=true
	game.start_game([SynkChart.note(4,4)],true);game.countdown=0;game.resume_countdown=0
	game.features.effects["Lasers"]=1.0
	var state=game.ssrg_presentation;var world=game.field.world;var fx=world.ssrg_theme
	state.reset(100)
	check(state.state==0 and state.collected==0 and state.cards.is_empty(),"Run reset has no invented events or inventory")
	check(state.profile_color(2).is_equal_approx(Color(0,.7843136787,1,1)),"First fever beam uses source scene color")
	game.score_panel.energy=1;state.judged("PERFECT")
	check(state.state==1,"Full real energy starts the offline fever entry state")
	for i in 5:state.judged("PERFECT")
	check(state.state==2,"Packaged ten-point threshold advances after five super-perfect hits")
	state._process(.5)
	check(is_equal_approx(float(state.weights[0]),.5),"Source fever fades in over one second")
	var before=state.phase_weights.duplicate();game.paused_mode="play";game.set_mode("paused");state._process(.5)
	check(state.phase_weights==before,"Pause freezes all fever transitions")
	game.set_mode("play");state._process(.5)
	check(is_equal_approx(float(state.weights[0]),1.0),"Fever reaches full opacity")
	state.select_state(3);state._process(.5)
	check(is_equal_approx(float(state.weights[0]),.5) and is_equal_approx(float(state.weights[1]),.5),"Old and new particle profiles crossfade together")
	fx._process(.016)
	check(fx.background_bank.size()==4,"Four prebuilt source particle profiles")
	check(fx.background_bank[0].visible and fx.background_bank[1].visible,"Both particle profiles render during transition")
	for type in 5:
		for item in 6:
			for phase in [0.0,.25,.5,.99]:check(state.special_art(type,item,phase)!=null,"Source special note artwork exists")
	var saved=SynkChart.note(4,3);saved.ssrg_order=17
	var source_notes=[saved];var runtime_notes=source_notes.duplicate(true)
	state.apply_events(runtime_notes,{"events":[{"order":17,"type":0},{"order":22,"type":99}]})
	check(runtime_notes[0].get("ssrg_special",-1)==0 and not saved.has("ssrg_special"),"Supplied events apply only to runtime copies")
	var special=runtime_notes[0]
	world.build_note_node("special",special)
	var head=world.notes.special.node.get_child(0)
	check(head.material_override.has_meta("ssrg_special"),"Special note has isolated source artwork")
	state.judged("PERFECT",special)
	check(state.collected==1 and state.event_kind==0,"Actual successful collection triggers collection display")
	state.judged("PERFECT",special)
	check(state.collected==1,"A repeated sustain/checkpoint notification cannot collect the same event twice")
	state.judged("MISS",special)
	check(state.collected==1 and state.state==0,"Miss resets fever and cannot collect a reward")
	fx.spawn(3,"special",{},-999)
	check(fx.hits[-1].frames==fx.special_frames,"Special events use source B flash sequence")
	world.miss_shake_remaining=0;world.ssrg_shake_x=0;world.apply_camera()
	var baseline_touch=game.field.touch_world_position(Vector2(.5,.85))
	world.shake_on_miss();world.animate_miss_shake(.1)
	check(game.field.touch_world_position(Vector2(.5,.85)).is_equal_approx(baseline_touch),"Visual miss shake cannot move calibrated input channels")
	check(is_equal_approx(world.ssrg_shake_x,-20.0*world.SSRG_UNIT),"Native miss begins with twenty-source-pixel displacement")
	var remaining=world.miss_shake_remaining;world.shake_on_miss()
	check(is_equal_approx(remaining,world.miss_shake_remaining),"An active miss shake is not restarted by another miss")
	world.animate_miss_shake(.1);world.animate_miss_shake(.1);world.animate_miss_shake(.01)
	check(is_zero_approx(world.ssrg_shake_x),"Native miss returns to zero after 300 ms")
	game.paused_mode="play";game.set_mode("paused");game.ssrg_screens._process(.2)
	check(game.ssrg_screens.pause_root.visible and not game.modal.visible,"SSRG pause replaces generic modal")
	var info={"ssrg":true,"ssrg_lane_count":7,"ssrg_style":"gold","title":"Fixture","score":12345,"accuracy":98.5,"max_combo":33,"counts":{"PERFECT":30,"GREAT":2,"GOOD":1,"MISS":0}}
	game.set_mode("results");game.ssrg_screens.show_results(info);game.ssrg_screens._process(.2)
	check(game.ssrg_screens.result_root.visible and game.ssrg_screens.result_score.text==game.format_score(12345),"Source results display actual run score")
	game.ssrg_screens.retry()
	check(game.ssrg_playable_run and game.ssrg_lane_count==7 and game.mode=="play","Results retry restores SSRG run and lane count")
	game.set_mode("menu");game.ssrg_screens._process(0)
	check(game.ssrg_screens.result_info.is_empty(),"Leaving results discards stale source screen data")
	game.start_game([SynkChart.note(4,4)],true)
	check(not game.uses_ssrg_gameplay() and game.score_panel.visible,"Regular play remains SYNK OG after every source transition")
	game.queue_free();await process_frame
	print("SSRG presentation systems failures: ",failures);quit(failures)
