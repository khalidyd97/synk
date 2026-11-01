extends SceneTree
const Scores=preload("res://scripts/ssrg_score_rules.gd")
var game
var failures=0
func check(ok:bool,label:String):
	if not ok:failures+=1;push_error(label)
func freeze(node:Node):
	node.set_process(false)
	for child in node.get_children():freeze(child)
func _initialize():run.call_deferred()
func run():
	var model=Scores.new();model.reset(100,13)
	check(model.add("PERFECT",2)==600,"Neutral card source note score and super-perfect rate")
	check(is_equal_approx(model.pending_bonus,30),"Rave adds base times level bonus, independent of grade rate")
	check(model.add("GOOD",2)==750,"GOOD scores half the base, no combo multiplier")
	check(model.settle()==810 and model.pending_bonus==0,"Rave settlement pays exactly once")
	check(model.settle()==810,"Repeated settlement cannot duplicate a bonus")
	model.reset(100,13,{"card_points":7});check(model.add("PERFECT",0)==2000,"Explicit numeric card points affect source base")
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame;freeze(game)
	game.stage_intro_enabled=false;game.ssrg_playable_run=true;game.ssrg_lane_count=13
	game.start_game([SynkChart.note(5,4)],false);game.countdown=0;game.gameplay_start_lead=0
	while game.field.world.prebuilding:game.field.world.step_prebuild()
	var state=game.ssrg_presentation
	state.reset(100)
	check(state.life==100 and state.gauge_fraction()==1,"Source run starts with full life")
	state.judged("PERFECT");check(state.state==1,"Full life enters fever entry on first successful judgment")
	state.judged("MISS");check(state.state==0 and state.life==70,"Hard miss deducts thirty life")
	state.judged("GOOD");check(state.life==70,"GOOD does not recover source life")
	for i in 90:state.judged("PERFECT")
	check(state.state==1 and state.life==100,"Hard recovery returns to entry using packaged one-third point rate")
	for i in 5:state.judged("PERFECT")
	check(state.state==2,"Source ten-point entry threshold")
	state.select_state(3)
	for i in 10:state.judged("GOOD")
	check(state.state==2,"Exhausted entry budget drops one level")
	var note=SynkChart.note(0,4,"slide");note.duration=5.0
	var entry={"note":note,"key":"retained","pointer":-999,"started":true,"done":false,"sustain_last_pointer":7,"sustain_last_identity":42}
	game.live=[entry];game.live_cursor=0;game.song_time=4.9
	game.pointers={7:{"ssrg_identity":42,"world":Vector3.ZERO,"ssrg_ui":Vector2(0,-230),"ssrg_phase":2}}
	check(game.ssrg_sustain_owner(entry)==7,"Lost track retains only its physical owner for autoaim")
	game.prepare_ssrg_input();check(game.pointers[7].ssrg_sustain_active,"Retained finger can re-enter sustain autoaim")
	game.pointers[7].ssrg_identity=43
	check(game.ssrg_sustain_owner(entry)==-999,"Reused finger index cannot acquire the old chain")
	game.pointers.clear();game.field.world.ssrg_theme.clear_hits()
	game.field.world.ssrg_theme.spawn(4,"slide",entry,-999)
	var hit_count=game.field.world.ssrg_theme.hits.size()
	game.pass_checkpoint(entry,1.0,0,"PERFECT")
	check(game.field.world.ssrg_theme.hits.size()==hit_count,"Checkpoints reuse the finger-following effect rather than flashing on the trail")
	game.song_time=1.0;game.audio.play(1.0)
	game.toggle_pause(false)
	check(game.mode=="paused" and is_equal_approx(game.ssrg_resume_position,1.0-game.effective_timing_ms()/1000.0),"Pause captures calibrated audio resume position")
	game.toggle_pause(false);game.audio.stop()
	game.resume_countdown=.001;game._process(.01)
	check(game.audio.playing and game.ssrg_resume_position<0,"Resume restores audio even when its handle stopped during interruption")
	game.audio.stop();game.song_time=1.5;game.toggle_pause(false)
	check(is_equal_approx(game.ssrg_resume_position,1.5-game.effective_timing_ms()/1000.0),"A handle lost before focus notification still resumes from the chart position")
	game.toggle_pause(false);game.resume_countdown=.001;game._process(.01)
	check(game.audio.playing and game.ssrg_resume_position<0,"Already-lost audio handle is recreated on resume")
	game.audio.stop();game.auto_play=true
	var results=[]
	for fps in [30,60,120]:
		var sustain={"note":note,"sustain_grade":"PERFECT","ssrg_tick_at":0.0}
		game.combo=0;game.judged=0;state.reset(100)
		for frame in range(1,ceili(1.237*fps)+1):
			game.song_time=minf(1.237,float(frame)/fps)
			game.update_ssrg_held_ticks(sustain)
		results.append([game.combo,game.score])
		check(game.judged==0,"Held ticks never inflate judgment statistics")
	check(results[0]==results[1] and results[1]==results[2] and results[0][0]>0,"Held tick combo and score remain identical at 30/60/120 FPS")
	game.queue_free();await process_frame
	print("SSRG native lifecycle failures: ",failures);quit(failures)
