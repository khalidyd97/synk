extends SceneTree
var failures=0
func check(ok: bool,message: String):
    if not ok: failures+=1; push_error(message)
func _initialize(): run.call_deferred()
func run():
    var g=load("res://scenes/main.tscn").instantiate(); root.add_child(g); await process_frame
    g.set_process(false); g.stage_intro_enabled=false; g.set_mode("editor")
    var notes=[SynkChart.note(2,0),SynkChart.note(3,2),SynkChart.note(8,1)]
    g.document.load_notes(notes)
    check(not g.practice.launch(notes,4,5,.5,true) and g.mode=="editor","Empty practice leaves editor unchanged")
    check(g.practice.launch(notes,2,4,.5,true),"Practice starts selected range")
    check(g.live.size()==2 and g.audio.pitch_scale==.5 and g.play_finish_time==4,"Practice filters notes and slows playback")
    g.countdown=0; g.song_time=1.97; g.live[0].timing_error=-.03; g.judge(g.live[0],.03)
    check(g.timing_label.text=="EARLY 30 ms" and g.timing_samples[0].ms==-30,"Signed early feedback")
    g.song_time=3.06; g.live[1].timing_error=.06; g.judge(g.live[1],.06)
    check(g.timing_label.text=="LATE 60 ms" and g.timing_samples.size()==2,"Signed late feedback")
    g._audio_finished()
    check(g.practice.round_number==2 and g.mode=="play" and g.score==0,"Practice repeat resets judgments and scores")
    check(not g.prefs.has_section("scores"),"Practice loop never saves a score")
    g.toggle_pause(); g.restart_from_pause()
    check(g.practice.active and g.practice.round_number==3 and g.audio.pitch_scale==.5,"Quick restart preserves practice configuration")
    g.practice.repeat_enabled=false; g.countdown=0; g.song_time=2; g.judge(g.live[0],0)
    check(g.timing_label.text=="ON TIME","On-time feedback")
    g._audio_finished()
    check(g.finishing and g.pending_results.practice and not g.pending_results.new_best,"Single practice produces unranked result")
    check(is_equal_approx(float(g.pending_results.accuracy),50),"Partial accuracy uses fractional division")
    check(not g.prefs.has_section("scores"),"Single practice never saves personal best")
    g.set_mode("results"); g.results_screen.show_results(g.pending_results)
    g.finish_overlay.stop(); g.finishing=false; g.results_screen.elapsed=2; g.results_screen.animate()
    g.results_screen.breakdown.visible=false; g.results_screen.timing_graph.visible=true
    for i in 3: await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://.tools/practice-timing.png")
    check(g.results_screen.rank_label.text=="PRACTICE","Results clearly identify practice")
    g.practice.restart(); g.toggle_pause(); g.return_home()
    check(g.mode=="editor" and not g.practice.active and g.document.notes==notes,"Practice exit returns intact editor chart")
    g.start_game(notes,true,"full"); g.song_time=2; g.judge(g.live[0],0)
    check(g.timing_samples.is_empty(),"Autoplay excluded from timing samples")
    g.audio.stop(); g.set_mode("editor"); g.cursor=0; g.features.open_tools("Practice")
    var page=g.features.tabs.get_node("Practice").get_child(0)
    for child in page.get_children():
        if child is HBoxContainer:
            for input in child.get_children():
                if input is OptionButton: input.select(0)
    page.get_children().back().pressed.emit()
    check(g.practice.active and g.practice.speed==.25 and g.features.overlay==null,"Practice UI starts exact selected speed and closes overlay")
    g.audio.stop(); g.queue_free(); await process_frame
    print("Practice and timing feedback: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
