extends SceneTree
var failures=0
func check(ok: bool,message: String):
    if not ok: failures+=1; push_error(message)
func _initialize(): run.call_deferred()
func run():
    var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); await process_frame
    game.set_process(false); game.stage_intro_enabled=false
    game.document.load_notes([]); game.cursor=10; game.record_speed=1
    game.record_here(); game.record_speed_button.pressed.emit()
    check(is_equal_approx(game.audio.pitch_scale,.75),"Recorder changes to 0.75 speed")
    game.record_speed_button.pressed.emit()
    check(is_equal_approx(game.audio.pitch_scale,.5),"Recorder changes to half speed")
    game.countdown=0; game.song_time=10; game.audio.play(10)
    var started=Time.get_ticks_msec()
    await create_timer(.5).timeout
    var elapsed=float(Time.get_ticks_msec()-started)/1000
    check(absf(game.audio.get_playback_position()-10-elapsed*.5)<.15,"Half speed advances in chart seconds")
    game.capture.begin(0,10,Vector2(.5,.8),"hold")
    game.song_time=game.chart_time(); game.capture.end(0,game.song_time,Vector2(.5,.8))
    check(game.capture.notes.size()==1 and absf(game.capture.notes[0].duration-elapsed*.5)<.15,"Notes retain source chart timing")
    game.toggle_pause(); game.toggle_pause()
    check(is_equal_approx(game.audio.pitch_scale,.5),"Pause and resume preserve speed")
    game.resume_countdown=0; game.toggle_arrange(); game.toggle_arrange()
    check(is_equal_approx(game.audio.pitch_scale,.5),"Arrange and record preserve speed")
    game.stop_take(); check(is_equal_approx(game.audio.pitch_scale,1),"Stop restores normal playback")
    game.record_here(); check(is_equal_approx(game.audio.pitch_scale,.5),"Next take remembers speed")
    game.toggle_pause(); game.restart_from_pause()
    check(is_equal_approx(game.audio.pitch_scale,.5),"Restart preserves speed")
    for i in 4: game.record_speed_button.pressed.emit()
    check(is_equal_approx(game.record_speed,1),"Speed options wrap to normal")
    check(is_equal_approx(float(game.prefs.get_value("editor","record_speed")),1),"Speed is persisted")
    game.stop_take(); game.start_game(SynkChart.demo())
    check(is_equal_approx(game.audio.pitch_scale,1),"Gameplay runs at normal speed")
    game.audio.stop(); game.queue_free(); await process_frame
    print("Recorder speed integration: ","PASS" if failures==0 else str(failures)+" FAILED"); quit(0 if failures==0 else 1)
