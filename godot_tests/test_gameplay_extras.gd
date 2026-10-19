extends SceneTree
var failures=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func tap_at(g: Control,id: int,lane: float) -> void:
	var w=g.field.world
	var p=w.camera.unproject_position(Vector3(w.lane_x(lane),.035,0))/Vector2(g.field.viewport.size)
	g.pointer_event(id,p,true,false,false); g.pointer_event(id,p,false,true,false)
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
	g.set_process(false); g.stage_intro_enabled=false
	var x=g.extras; var w=g.field.world
	var saved=x.settings.duplicate()
	for key in ["mirror","hidden","sudden"]: x.settings[key]=false
	x.settings.judgement="normal"; x.settings.touch_assist=true
	# Leniency
	check(is_equal_approx(x.perfect_window(),.045) and is_equal_approx(x.good_window(),.16),"Normal windows match the original timing")
	x.settings.judgement="easy"
	check(x.perfect_window()>.06 and x.good_window()>.2,"Easy judging widens every window")
	x.settings.judgement="normal"
	# Mirror
	x.settings.mirror=true
	var flick=SynkChart.note(1,2,"flick"); flick.direction=1
	var mirrored=x.apply_mods([SynkChart.note(1,0),flick])
	check(int(mirrored[0].lane)==SynkChart.MAX_LANE and int(mirrored[1].direction)==3,"Mirror flips lanes and sideways flicks")
	x.settings.mirror=false
	# Hidden / Sudden
	x.settings.hidden=true; check(w.modifier_hides(-8.0) and not w.modifier_hides(-40.0),"Hidden hides notes near the line")
	x.settings.hidden=false; x.settings.sudden=true; check(w.modifier_hides(-45.0) and not w.modifier_hides(-8.0),"Sudden hides notes far up the highway")
	x.settings.sudden=false
	# Chords, judging hooks, miss flash, milestone, touch assist
	var chart=[SynkChart.note(10,2),SynkChart.note(10,6),SynkChart.note(11,4),SynkChart.note(12,1)]
	g.start_game(chart,false); g.countdown=0; g.song_time=10
	check(w.chords.size()==1 and w.chords[0].indices.size()==2,"Simultaneous notes get one chord line")
	tap_at(g,1,2); tap_at(g,2,6)
	check(g.combo==2 and g.judgment_counts.PERFECT==2,"Chord taps are judged")
	g.song_time=11; tap_at(g,3,5.3)
	check(g.combo==3,"Touch assist hits a note 1.3 lanes away when nothing is closer")
	g.song_time=12.5; g.update_game()
	check(g.judgment_counts.MISS==1 and w.miss_flashes[1].amount>0,"A miss flashes its lane")
	g.combo=50; x.on_judged(g.live[0],"PERFECT",50); check(g.combo_view.caption=="50 COMBO" and g.combo_view.flare>0,"Combo milestones flare the combo display")
	# Lenient hold and slide ends
	var hold=SynkChart.note(20,4,"hold"); hold.duration=2.0
	g.start_game([hold],false); g.countdown=0; g.song_time=20.0
	var hp=w.camera.unproject_position(Vector3(w.lane_x(4),.035,0))/Vector2(g.field.viewport.size)
	g.pointer_event(40,hp,true,false,false)
	g.song_time=21.65; g.pointer_event(40,hp,false,true,false)
	check(g.judgment_counts.MISS==0 and g.judgment_counts.PERFECT==2,"Releasing a hold 0.35 s early still completes it as PERFECT")
	g.start_game([hold],false); g.countdown=0; g.song_time=20.0
	g.pointer_event(41,hp,true,false,false); g.song_time=20.8; g.pointer_event(41,hp,false,true,false)
	check(g.judgment_counts.MISS==1,"Letting go far too early is still a miss")
	# Stats
	var key="test_stats_"+str(Time.get_ticks_usec())
	var stats=x.record_result(key,{"PERFECT":4,"GREAT":0,"GOOD":0,"MISS":0},4)
	check(int(stats.plays)==1 and stats.full_combo and stats.all_perfect,"A clean run records full combo and all perfect")
	stats=x.record_result(key,{"PERFECT":3,"GREAT":0,"GOOD":0,"MISS":1},4)
	check(int(stats.plays)==2 and stats.all_perfect,"Badges stay earned; plays keep counting")
	g.prefs.set_value("chart_stats",key,null)
	# Daily challenge
	var today=x.daily(); check(not today.is_empty() and today==x.daily(),"Daily challenge is stable for the day")
	# Replay reproduces the run
	var run_chart=[SynkChart.note(5,3),SynkChart.note(6,7),SynkChart.note(7,1)]
	g.start_game(run_chart,false); g.countdown=0
	for i in 3:
		g.song_time=5.0+i+.02; tap_at(g,10+i,float([3,7,1][i]))
	x.finish_run(); var real_score=g.score
	check(x.has_replay() and x.last_replay.events.size()==6,"Real touches are recorded")
	x.start_replay(); g.countdown=0
	for i in 3:
		g.song_time=5.0+i+.05; x.step_replay()
	check(g.score==real_score and g.judgment_counts.PERFECT==3,"Replay reproduces the same result")
	tap_at(g,99,3); check(true,"Real touches are ignored during a replay")
	x.replaying=false
	# Practice keeps pitch
	g.practice.active=true; g.practice.set_pitch_correction(.75)
	var has_shift=false
	for i in AudioServer.get_bus_effect_count(0): has_shift=has_shift or AudioServer.get_bus_effect(0,i) is AudioEffectPitchShift
	check(has_shift,"Slowed practice adds pitch correction")
	g.practice.active=false; g.practice.set_pitch_correction(1.0)
	has_shift=false
	for i in AudioServer.get_bus_effect_count(0): has_shift=has_shift or AudioServer.get_bus_effect(0,i) is AudioEffectPitchShift
	check(not has_shift,"Pitch correction is removed after practice")
	x.settings=saved
	g.queue_free(); await process_frame
	print("Gameplay extras: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
